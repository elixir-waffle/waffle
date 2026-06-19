defmodule Waffle.Storage.Azure do
  @moduledoc ~S"""
  The module to facilitate integration with Azure Blob Storage

      config :waffle,
        storage: Waffle.Storage.Azure,
        storage_account: {:system, "AZURE_STORAGE_ACCOUNT"},
        container: {:system, "AZURE_STORAGE_CONTAINER"},
        access_key: {:system, "AZURE_ACCESS_KEY"}

  Along with any configuration necessary for Azure Blob Storage.

  To store your attachments in Azure Blob Storage, you'll need to provide a
  storage account, container, and access key in your application config:

      config :waffle,
        storage_account: "mystorageaccount",
        container: "uploads",
        access_key: "your-access-key"

  You may also set these values from environment variables:

      config :waffle,
        storage_account: {:system, "AZURE_STORAGE_ACCOUNT"},
        container: {:system, "AZURE_STORAGE_CONTAINER"},
        access_key: {:system, "AZURE_ACCESS_KEY"}

  ## Specify multiple containers

  Waffle lets you specify a container on a per definition basis. In case
  you want to use multiple containers, you can specify a container in the
  definition module like this:

      def container, do: :some_custom_container_name

  You can also use the current scope to define a target container

      def container({_file, scope}), do: scope.container || container()

  ## Public vs Private Access

  Waffle defaults all uploads to private. In cases where it is desired to have
  your uploads public, you may set the public access at the module level:

      @public_access true

  Or you may have more granular control over each version:

      def public_access(:thumb, _), do: true

  When public access is disabled, Waffle will generate SAS (Shared Access Signature)
  tokens for secure access to the blobs.

  ## Azure Blob Headers

  The definition module may specify custom headers to pass through to
  Azure Blob Storage during object creation. The available custom headers include:

    *  `:cache_control`
    *  `:content_disposition`
    *  `:content_encoding`
    *  `:content_type`
    *  `:content_language`
    *  `:content_md5`

  As an example, to explicitly specify the content-type of an object,
  you may define a `azure_blob_headers/2` function in your definition,
  which returns a Keyword list, or Map of desired headers.

      def azure_blob_headers(version, {file, scope}) do
        [content_type: MIME.from_path(file.file_name)] # for "image.png", would produce: "image/png"
      end

  ## Configuration example

  A full example configuration for Azure Blob Storage is as follows:

      config :waffle,
        storage: Waffle.Storage.Azure,
        storage_account: "mystorageaccount",
        container: "uploads",
        access_key: "your-access-key",
        public_access: false,
        expiry_in_minutes: 60

  """

  require Logger

  @behaviour Waffle.StorageBehavior

  alias Waffle.Definition.Versioning

  @default_expiry_time 60 * 60  # 1 hour in seconds

  @impl true
  def put(definition, version, {file, scope}) do
    blob_name = build_blob_name(definition, version, {file, scope})
    container = azure_container(definition, {file, scope})

    blob_headers =
      definition.azure_blob_headers(version, {file, scope})
      |> ensure_keyword_list()

    do_put(file, {container, blob_name, blob_headers})
  end

  @impl true
  def url(definition, version, file_and_scope, options \\ []) do
    case Keyword.get(options, :signed, false) do
      false -> build_url(definition, version, file_and_scope, options)
      true -> build_signed_url(definition, version, file_and_scope, options)
    end
  end

  @impl true
  def delete(definition, version, {file, scope}) do
    blob_name = build_blob_name(definition, version, {file, scope})
    container = azure_container(definition, {file, scope})

    case Waffle.Storage.Azure.Uploader.delete_blob(container, blob_name) do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end

  #
  # Private
  #

  defp ensure_keyword_list(list) when is_list(list), do: list
  defp ensure_keyword_list(map) when is_map(map), do: Map.to_list(map)

  # If the file is stored as a binary in-memory, send to Azure in a single request
  defp do_put(file = %Waffle.File{binary: file_binary}, {container, blob_name, blob_headers})
       when is_binary(file_binary) do
    case Waffle.Storage.Azure.Uploader.upload_file(file_binary, container, blob_name, blob_headers) do
      {:ok, _} -> {:ok, file.file_name}
      {:error, error} -> {:error, error}
    end
  end

  # If the file is a stream, read it and upload to Azure
  defp do_put(file = %Waffle.File{stream: file_stream}, {container, blob_name, blob_headers})
       when is_struct(file_stream) do
    file_binary = file_stream |> Enum.into(<<>>)
    do_put(%{file | binary: file_binary}, {container, blob_name, blob_headers})
  end

  # Stream the file and upload to Azure
  defp do_put(file, {container, blob_name, blob_headers}) do
    case File.read(file.path) do
      {:ok, file_binary} ->
        do_put(%{file | binary: file_binary}, {container, blob_name, blob_headers})
      {:error, reason} ->
        Logger.error("[AzureStorage] File read failed: #{reason}")
        {:error, "File read failed: #{reason}"}
    end
  end

  defp build_url(definition, version, file_and_scope, _options) do
    blob_name = build_blob_name(definition, version, file_and_scope)
    container = azure_container(definition, file_and_scope)
    storage_account = azure_storage_account(definition, file_and_scope)

    "https://#{storage_account}.blob.core.windows.net/#{container}/#{blob_name}"
  end

  defp build_signed_url(definition, version, file_and_scope, options) do
    blob_name = build_blob_name(definition, version, file_and_scope)
    container = azure_container(definition, file_and_scope)
    storage_account = azure_storage_account(definition, file_and_scope)
    access_key = azure_access_key(definition, file_and_scope)

    # Get expiry time from options or use default
    expiry_in_seconds = Keyword.get(options, :expires_in, @default_expiry_time)

    case Waffle.Storage.Azure.SAS.generate_sas_url(
           storage_account,
           container,
           blob_name,
           access_key,
           expiry_in_seconds
         ) do
      {:ok, url} -> url
      {:error, reason} ->
        Logger.error("[AzureStorage] Failed to generate signed URL: #{reason}")
        build_url(definition, version, file_and_scope, options)
    end
  end

  defp build_blob_name(definition, version, file_and_scope) do
    Path.join([
      definition.storage_dir(version, file_and_scope),
      Versioning.resolve_file_name(definition, version, file_and_scope)
    ])
  end

  defp azure_container(definition, file_and_scope) do
    definition.container(file_and_scope) |> parse_config_value()
  end

  defp azure_storage_account(definition, file_and_scope) do
    definition.storage_account(file_and_scope) |> parse_config_value()
  end

  defp azure_access_key(definition, file_and_scope) do
    definition.access_key(file_and_scope) |> parse_config_value()
  end

  defp parse_config_value({:system, env_var}) when is_binary(env_var), do: System.get_env(env_var)
  defp parse_config_value(value), do: value
end
