defmodule Waffle.Storage.Local do
  @moduledoc ~S"""
  Local storage provides facility to store files locally.

  ## Local configuration

      config :waffle,
        storage: Waffle.Storage.Local,
        # in order to have a different storage directory from url
        storage_dir_prefix: "priv/waffle/private",
        # add custom host to url
        asset_host: "https://example.com"

  If you want to handle your attachements by phoenix application,
  configure the endpoint to serve it.

      defmodule AppWeb.Endpoint do
        plug Plug.Static,
          at: "/uploads",
          from: Path.expand("./priv/waffle/public/uploads"),
          gzip: false
      end
  """

  alias Waffle.Definition.Versioning

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
      Versioning.resolve_file_name(definition, version, file_and_scope)
    ])
    host = host(definition)

    if host == nil do
      Path.join("/", local_path)
    else
      Path.join([host, local_path])
    end
    |> URI.encode()
  end

  def delete(definition, version, file_and_scope) do
    Path.join([
      definition.storage_dir_prefix(),
      definition.storage_dir(version, file_and_scope),
      Versioning.resolve_file_name(definition, version, file_and_scope)
    ])
    |> File.rm()
  end

  defp host(definition) do
    case definition.asset_host() do
      {:system, env_var} when is_binary(env_var) -> System.get_env(env_var)
      url -> url
    end
  end
end
