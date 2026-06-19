# Azure Blob Storage

This guide will help you set up Waffle to work with Azure Blob Storage.

## Configuration

Add the following to your `config/config.exs`:

```elixir
config :waffle,
  storage: Waffle.Storage.Azure,
  storage_account: {:system, "AZURE_STORAGE_ACCOUNT"},
  container: {:system, "AZURE_STORAGE_CONTAINER"},
  access_key: {:system, "AZURE_ACCESS_KEY"},
  public_access: false,
  expiry_in_minutes: 60
```

Or with direct values:

```elixir
config :waffle,
  storage: Waffle.Storage.Azure,
  storage_account: "mystorageaccount",
  container: "uploads",
  access_key: "your-access-key",
  public_access: false,
  expiry_in_minutes: 60
```

## Environment Variables

Set the following environment variables:

```bash
export AZURE_STORAGE_ACCOUNT="mystorageaccount"
export AZURE_STORAGE_CONTAINER="uploads"
export AZURE_ACCESS_KEY="your-access-key"
```

## Definition Module

Create a definition module for your uploads:

```elixir
defmodule MyApp.Avatar do
  use Waffle.Definition

  @extension_whitelist ~w(.jpg .jpeg .gif .png)

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    case Enum.member?(@extension_whitelist, file_extension) do
      true -> :ok
      false -> {:error, "invalid file type"}
    end
  end

  def storage_dir(version, {file, scope}) do
    "uploads/users/avatars/#{scope.id}"
  end

  # Optional: Override container per definition
  def container({_file, scope}), do: scope.container || container()

  # Optional: Override storage account per definition
  def storage_account({_file, scope}), do: scope.storage_account || storage_account()

  # Optional: Custom Azure blob headers
  def azure_blob_headers(version, {file, scope}) do
    [content_type: MIME.from_path(file.file_name)]
  end
end
```

## Usage

### Storing Files

```elixir
# Store a file
{:ok, file_name} = MyApp.Avatar.store({%Plug.Upload{path: "/tmp/avatar.jpg", filename: "avatar.jpg"}, user})

# Store with custom scope
{:ok, file_name} = MyApp.Avatar.store({%Plug.Upload{path: "/tmp/avatar.jpg", filename: "avatar.jpg"}, %{id: 123, container: "custom-container"}})
```

### Generating URLs

```elixir
# Generate public URL (if public_access is true)
url = MyApp.Avatar.url({file_name, user})

# Generate signed URL (if public_access is false)
url = MyApp.Avatar.url({file_name, user}, signed: true)

# Generate signed URL with custom expiry
url = MyApp.Avatar.url({file_name, user}, signed: true, expires_in: 3600) # 1 hour
```

### Deleting Files

```elixir
# Delete a file
:ok = MyApp.Avatar.delete({file_name, user})
```

## Multiple Containers

You can use different containers for different uploaders:

```elixir
defmodule MyApp.Document do
  use Waffle.Definition

  def container, do: "documents"
end

defmodule MyApp.Image do
  use Waffle.Definition

  def container, do: "images"
end
```

## Public vs Private Access

### Public Access

When `public_access` is set to `true`, files are accessible via direct URLs without authentication:

```elixir
config :waffle,
  public_access: true
```

### Private Access (Default)

When `public_access` is `false` (default), files are accessed via signed URLs with SAS tokens:

```elixir
config :waffle,
  public_access: false,
  expiry_in_minutes: 60  # SAS token expires in 60 minutes
```

## Custom Headers

You can specify custom headers for Azure blob storage:

```elixir
def azure_blob_headers(version, {file, scope}) do
  [
    content_type: MIME.from_path(file.file_name),
    cache_control: "public, max-age=31536000",
    content_disposition: "inline; filename=\"#{file.file_name}\""
  ]
end
```

## Dependencies

Make sure to add the required dependencies to your `mix.exs`:

```elixir
defp deps do
  [
    {:waffle, "~> 1.1"},
    {:req, "~> 0.4"},
    {:timex, "~> 3.7"}
  ]
end
```

## Error Handling

The Azure storage adapter will return appropriate error tuples:

```elixir
case MyApp.Avatar.store({file, user}) do
  {:ok, file_name} ->
    # Success
  {:error, reason} ->
    # Handle error
end
```

Common error scenarios:

- Invalid storage account or container
- Missing access key
- Network connectivity issues
- File read errors
