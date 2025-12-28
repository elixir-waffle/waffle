# Example configuration for Azure Blob Storage with Waffle
# Add this to your config/config.exs or config/prod.exs

# Basic Azure configuration
config :waffle,
  storage: Waffle.Storage.Azure,
  storage_account: {:system, "AZURE_STORAGE_ACCOUNT"},
  container: {:system, "AZURE_STORAGE_CONTAINER"},
  access_key: {:system, "AZURE_ACCESS_KEY"},
  public_access: false,
  expiry_in_minutes: 60

# Example definition module
defmodule Example.Avatar do
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

  # Optional: Custom Azure blob headers
  def azure_blob_headers(version, {file, scope}) do
    [content_type: MIME.from_path(file.file_name)]
  end
end

# Example usage:
# {:ok, file_name} = Example.Avatar.store({%Plug.Upload{path: "/tmp/avatar.jpg", filename: "avatar.jpg"}, user})
# url = Example.Avatar.url({file_name, user}, signed: true)
# :ok = Example.Avatar.delete({file_name, user})
