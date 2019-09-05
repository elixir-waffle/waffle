defmodule Waffle.Storage.Local do
  @moduledoc ~S"""
  Local storage provides facility to store files locally.

  ## Local configuration

      config :waffle,
        storage: Waffle.Storage.Local,
        # in order to have a different storage directory from url
        starage_dir_prefix: "priv/waffle/private"

  If you want to handle your attachements by phoenix application, configure the endpoint to serve it.

      defmodule AppWeb.Endpoint do
        plug Plug.Static,
          at: "/uploads", from: Path.expand("./priv/waffle/public/uploads"), gzip: false
      end
  """

  def put(definition, version, {file, scope}) do
    destination_path = Path.join([
      definition.storage_dir_prefix(),
      definition.storage_dir(version, {file, scope}),
      file.file_name
    ])
    destination_path |> Path.dirname() |> File.mkdir_p!()

    if binary = file.binary do
      File.write!(destination_path, binary)
    else
      File.copy!(file.path, destination_path)
    end

    {:ok, file.file_name}
  end

  def url(definition, version, file_and_scope, _options \\ []) do
    local_path = Path.join([
      definition.storage_dir(version, file_and_scope),
      Waffle.Definition.Versioning.resolve_file_name(definition, version, file_and_scope)
    ])

    url = if String.starts_with?(local_path, "/") do
      local_path
    else
      "/" <> local_path
    end

    url |> URI.encode()
  end

  def delete(definition, version, file_and_scope) do
    Path.join([
      definition.storage_dir_prefix(),
      definition.storage_dir(version, file_and_scope),
      Waffle.Definition.Versioning.resolve_file_name(definition, version, file_and_scope)
    ])
    |> File.rm()
  end
end
