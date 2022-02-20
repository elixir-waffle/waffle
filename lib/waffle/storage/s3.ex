defmodule Waffle.Storage.S3 do
  @moduledoc ~S"""
  The module to facilitate integration with S3 through ExAws.S3

      config :waffle,
        storage: Waffle.Storage.S3,
        bucket: {:system, "AWS_S3_BUCKET"}

  Along with any configuration necessary for ExAws.

  [ExAws](https://github.com/CargoSense/ex_aws) is used to support Amazon S3.

  To store your attachments in Amazon S3, you'll need to provide a
  bucket destination in your application config:

      config :waffle,
        bucket: "uploads"

  You may also set the bucket from an environment variable:

      config :waffle,
        bucket: {:system, "S3_BUCKET"}

  In addition, ExAws must be configured with the appropriate Amazon S3
  credentials.

  ExAws has by default the following configuration (which you may
  override if you wish):

      config :ex_aws,
        json_codec: Jason,
        access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
        secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]

  This means it will first look for the AWS standard
  `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment
  variables, and fall back using instance meta-data if those don't
  exist. You should set those environment variables to your
  credentials, or configure an instance that this library runs on to
  have an iam role.

  ## Specify multiple buckets

  Waffle lets you specify a bucket on a per definition basis. In case
  you want to use multiple buckets, you can specify a bucket in the
  definition module like this:

      def bucket, do: :some_custom_bucket_name

  You can also use the current scope to define a target bucket

      def bucket({_file, scope}), do: scope.bucket || bucket()

  ## Access Control Permissions

  Waffle defaults all uploads to `private`.  In cases where it is
  desired to have your uploads public, you may set the ACL at the
  module level (which applies to all versions):

      @acl :public_read

  Or you may have more granular control over each version.  As an
  example, you may wish to explicitly only make public a thumbnail
  version of the file:

      def acl(:thumb, _), do: :public_read

  Supported access control lists for Amazon S3 are:

  | ACL                          | Permissions Added to ACL                                                        |
  |------------------------------|---------------------------------------------------------------------------------|
  | `:private`                   | Owner gets `FULL_CONTROL`. No one else has access rights (default).             |
  | `:public_read`               | Owner gets `FULL_CONTROL`. The `AllUsers` group gets READ access.               |
  | `:public_read_write`         | Owner gets `FULL_CONTROL`. The `AllUsers` group gets `READ` and `WRITE` access. |
  |                              | Granting this on a bucket is generally not recommended.                         |
  | `:authenticated_read`        | Owner gets `FULL_CONTROL`. The `AuthenticatedUsers` group gets `READ` access.   |
  | `:bucket_owner_read`         | Object owner gets `FULL_CONTROL`. Bucket owner gets `READ` access.              |
  | `:bucket_owner_full_control` | Both the object owner and the bucket owner get `FULL_CONTROL` over the object.  |

  For more information on the behavior of each of these, please
  consult Amazon's documentation for [Access Control List (ACL)
  Overview](https://docs.aws.amazon.com/AmazonS3/latest/dev/acl-overview.html).

  ## S3 Object Headers

  The definition module may specify custom headers to pass through to
  S3 during object creation.  The available custom headers include:

    *  `:cache_control`
    *  `:content_disposition`
    *  `:content_encoding`
    *  `:content_length`
    *  `:content_type`
    *  `:expect`
    *  `:expires`
    *  `:storage_class`
    *  `:website_redirect_location`
    *  `:encryption` (set to "AES256" for encryption at rest)

  As an example, to explicitly specify the content-type of an object,
  you may define a `s3_object_headers/2` function in your definition,
  which returns a Keyword list, or Map of desired headers.

      def s3_object_headers(version, {file, scope}) do
        [content_type: MIME.from_path(file.file_name)] # for "image.png", would produce: "image/png"
      end

  ## Alternate S3 configuration example

  If you are using a region other than US-Standard, it is necessary to
  specify the correct configuration for `ex_aws`.  A full example
  configuration for both waffle and ex_aws is as follows:

      config :waffle,
        bucket: "my-frankfurt-bucket"

      config :ex_aws,
        json_codec: Jason,
        access_key_id: "my_access_key_id",
        secret_access_key: "my_secret_access_key",
        region: "eu-central-1",
        s3: [
          scheme: "https://",
          host: "s3.eu-central-1.amazonaws.com",
          region: "eu-central-1"
        ]

  > For your host configuration, please examine the approved [AWS Hostnames](http://docs.aws.amazon.com/general/latest/gr/rande.html).  There are often multiple hostname formats for AWS regions, and it will not work unless you specify the correct one.

  """
  require Logger

  alias ExAws.Config
  alias ExAws.Request.Url
  alias ExAws.S3
  alias ExAws.S3.Upload
  alias Waffle.Definition.Versioning

  @default_expiry_time 60 * 5

  def put(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    s3_bucket = s3_bucket(definition, {file, scope})
    s3_key = Path.join(destination_dir, file.file_name)
    acl = definition.acl(version, {file, scope})

    s3_options =
      definition.s3_object_headers(version, {file, scope})
      |> ensure_keyword_list()
      |> Keyword.put(:acl, acl)

    do_put(file, {s3_bucket, s3_key, s3_options})
  end

  def url(definition, version, file_and_scope, options \\ []) do
    case Keyword.get(options, :signed, false) do
      false -> build_url(definition, version, file_and_scope, options)
      true -> build_signed_url(definition, version, file_and_scope, options)
    end
  end

  def delete(definition, version, {file, scope}) do
    s3_bucket(definition, {file, scope})
    |> S3.delete_object(s3_key(definition, version, {file, scope}))
    |> ExAws.request()

    :ok
  end

  #
  # Private
  #

  defp ensure_keyword_list(list) when is_list(list), do: list
  defp ensure_keyword_list(map) when is_map(map), do: Map.to_list(map)

  # If the file is stored as a binary in-memory, send to AWS in a single request
  defp do_put(file = %Waffle.File{binary: file_binary}, {s3_bucket, s3_key, s3_options})
       when is_binary(file_binary) do
    S3.put_object(s3_bucket, s3_key, file_binary, s3_options)
    |> ExAws.request()
    |> case do
      {:ok, _res} -> {:ok, file.file_name}
      {:error, error} -> {:error, error}
    end
  end

  # Stream the file and upload to AWS as a multi-part upload
  defp do_put(file, {s3_bucket, s3_key, s3_options}) do
    file.path
    |> Upload.stream_file()
    |> S3.upload(s3_bucket, s3_key, s3_options)
    |> ExAws.request()
    |> case do
      {:ok, %{status_code: 200}} -> {:ok, file.file_name}
      {:ok, :done} -> {:ok, file.file_name}
      {:error, error} -> {:error, error}
    end
  rescue
    e in ExAws.Error ->
      Logger.error(inspect(e))
      Logger.error(e.message)
      {:error, :invalid_bucket}
  end

  defp build_url(definition, version, file_and_scope, _options) do
    asset_path =
      s3_key(definition, version, file_and_scope)
      |> Url.sanitize(:s3)

    Path.join(host(definition, file_and_scope), asset_path)
  end

  defp build_signed_url(definition, version, file_and_scope, options) do
    # Previous waffle argument was expire_in instead of expires_in
    # check for expires_in, if not present, use expire_at.
    options = put_in(options[:expires_in], Keyword.get(options, :expires_in, options[:expire_in]))
    # fallback to default, if neither is present.
    options = put_in(options[:expires_in], options[:expires_in] || @default_expiry_time)
    options = put_in(options[:virtual_host], virtual_host())
    config = Config.new(:s3, Application.get_all_env(:ex_aws))
    s3_key = s3_key(definition, version, file_and_scope)
    s3_bucket = s3_bucket(definition, file_and_scope)
    {:ok, url} = S3.presigned_url(config, :get, s3_bucket, s3_key, options)
    url
  end

  defp s3_key(definition, version, file_and_scope) do
    Path.join([
      definition.storage_dir(version, file_and_scope),
      Versioning.resolve_file_name(definition, version, file_and_scope)
    ])
  end

  defp host(definition, file_and_scope) do
    case asset_host(definition, file_and_scope) do
      {:system, env_var} when is_binary(env_var) -> System.get_env(env_var)
      url -> url
    end
  end

  defp asset_host(definition, file_and_scope) do
    case definition.asset_host() do
      false -> default_host(definition, file_and_scope)
      nil -> default_host(definition, file_and_scope)
      host -> host
    end
  end

  defp default_host(definition, file_and_scope) do
    case virtual_host() do
      true -> "https://#{s3_bucket(definition, file_and_scope)}.s3.amazonaws.com"
      _ -> "https://s3.amazonaws.com/#{s3_bucket(definition, file_and_scope)}"
    end
  end

  defp virtual_host do
    Application.get_env(:waffle, :virtual_host) || false
  end

  defp s3_bucket(definition, file_and_scope) do
    definition.bucket(file_and_scope) |> parse_bucket()
  end

  defp parse_bucket({:system, env_var}) when is_binary(env_var), do: System.get_env(env_var)
  defp parse_bucket(name), do: name
end
