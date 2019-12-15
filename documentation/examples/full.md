# Full Example

```elixir
defmodule Avatar do
  use Waffle.Definition

  @versions [:original, :thumb]
  @extension_whitelist ~w(.jpg .jpeg .gif .png)

  def acl(:thumb, _), do: :public_read

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname |> String.downcase
    Enum.member?(@extension_whitelist, file_extension)
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

  def default_url(:thumb) do
    "https://placehold.it/100x100"
  end
end

# Given some current_user record
current_user = %{id: 1}

# Store any accessible file
Avatar.store({"/path/to/my/selfie.png", current_user}) #=> {:ok, "selfie.png"}

# ..or store directly from the `params` of a file upload within your controller
Avatar.store({%Plug.Upload{}, current_user}) #=> {:ok, "selfie.png"}

# and retrieve the url later
Avatar.url({"selfie.png", current_user}, :thumb) #=> "https://s3.amazonaws.com/bucket/uploads/avatars/1/thumb.png"
```
