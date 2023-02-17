# An Example for Local

Setup the storage provider:
```elixir
config :waffle,
  storage: Waffle.Storage.Local,
  asset_host: "http://static.example.com" # or {:system, "ASSET_HOST"}
```

Define a definition module:
```elixir
defmodule Avatar do
  use Waffle.Definition

  @versions [:original, :thumb]
  @extension_acceptlist ~w(.jpg .jpeg .gif .png)

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname |> String.downcase

    case Enum.member?(@extension_acceptlist, file_extension) do
      true -> :ok
      false -> {:error, "file type is invalid"}
    end
  end

  def transform(:thumb, _) do
    {:convert, "-thumbnail 100x100^ -gravity center -extent 100x100 -format png", :png}
  end

  def filename(version, _) do
    version
  end

  def storage_dir(_, {file, user}) do
    "uploads/avatars/#{user.id}"
  end
end
```

Store or Get files:
```elixir
# Given some current_user record
current_user = %{id: 1}

# Store any accessible file
Avatar.store({"/path/to/my/selfie.png", current_user})
#=> {:ok, "selfie.png"}

# ..or store directly from the `params` of a file upload within your controller
Avatar.store({%Plug.Upload{}, current_user})
#=> {:ok, "selfie.png"}

# and retrieve the url later
Avatar.url({"selfie.png", current_user}, :thumb)
#=> "uploads/avatars/1/thumb.png"
```
