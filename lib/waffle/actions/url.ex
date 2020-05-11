defmodule Waffle.Actions.Url do
  @moduledoc ~S"""
  Url generation.

  Saving your files is only the first half of any decent storage
  solution.  Straightforward access to your uploaded files is equally
  as important as storing them in the first place.

  Often times you will want to regain access to the stored files.  As
  such, `Waffle` facilitates the generation of urls.

      # Given some user record
      user = %{id: 1}

      Avatar.store({%Plug.Upload{}, user}) #=> {:ok, "selfie.png"}

      # To generate a regular, unsigned url (defaults to the first version):
      Avatar.url({"selfie.png", user})
      #=> "https://bucket.s3.amazonaws.com/uploads/1/original.png"

      # To specify the version of the upload:
      Avatar.url({"selfie.png", user}, :thumb)
      #=> "https://bucket.s3.amazonaws.com/uploads/1/thumb.png"

      # To generate a signed url:
      Avatar.url({"selfie.png", user}, :thumb, signed: true)
      #=> "https://bucket.s3.amazonaws.com/uploads/1/thumb.png?AWSAccessKeyId=AKAAIPDF14AAX7XQ&Signature=5PzIbSgD1V2vPLj%2B4WLRSFQ5M%3D&Expires=1434395458"

      # To generate urls for all versions:
      Avatar.urls({"selfie.png", user})
      #=> %{original: "https://.../original.png", thumb: "https://.../thumb.png"}

  **Default url**

  In cases where a placeholder image is desired when an uploaded file
  is not present, Waffle allows the definition of a default image to
  be returned gracefully when requested with a `nil` file.

      def default_url(version) do
        MyApp.Endpoint.url <> "/images/placeholders/profile_image.png"
      end

      Avatar.url(nil) #=> "http://example.com/images/placeholders/profile_image.png"
      Avatar.url({nil, scope}) #=> "http://example.com/images/placeholders/profile_image.png"

  **Virtual Host**

  To support AWS regions other than US Standard, it may be required to
  generate urls in the
  [`virtual_host`](http://docs.aws.amazon.com/AmazonS3/latest/dev/VirtualHosting.html)
  style.  This will generate urls in the style:
  `https://#{bucket}.s3.amazonaws.com` instead of
  `https://s3.amazonaws.com/#{bucket}`.

  To use this style of url generation, your bucket name must be DNS
  compliant.

  This can be enabled with:

      config :waffle,
        virtual_host: true

  > When using virtual hosted–style buckets with SSL, the SSL wild card certificate only matches buckets that do not contain periods. To work around this, use HTTP or write your own certificate verification logic.

  **Asset Host**

  You may optionally specify an asset host rather than using the
  default `bucket.s3.amazonaws.com` format.

  In your application configuration, you'll need to provide an `asset_host` value:

      config :waffle,
        asset_host: "https://d3gav2egqolk5.cloudfront.net", # For a value known during compilation
        asset_host: {:system, "ASSET_HOST"} # For a value not known until runtime

  """

  alias Waffle.Actions.Url
  alias Waffle.Definition.Versioning

  defmacro __using__(_) do
    quote do
      def urls(file, options \\ []) do
        Enum.into __MODULE__.__versions, %{}, fn(r) ->
          {r, __MODULE__.url(file, r, options)}
        end
      end

      def url(file), do: url(file, nil)
      def url(file, options) when is_list(options), do: url(file, nil, options)
      def url(file, version), do: url(file, version, [])
      def url(file, version, options), do: Url.url(__MODULE__, file, version, options)

      defoverridable [{:url, 3}]
    end
  end

  # Apply default version if not specified
  def url(definition, file, nil, options),
    do: url(definition, file, Enum.at(definition.__versions, 0), options)

  # Transform standalone file into a tuple of {file, scope}
  def url(definition, file, version, options) when is_binary(file) or is_map(file) or is_nil(file),
    do: url(definition, {file, nil}, version, options)

  # Transform file-path into a map with a file_name key
  def url(definition, {file, scope}, version, options) when is_binary(file) do
    url(definition, {%{file_name: file}, scope}, version, options)
  end

  def url(definition, {file, scope}, version, options) do
    build(definition, version, {file, scope}, options)
  end

  #
  # Private
  #

  defp build(definition, version, {nil, scope}, _options) do
    definition.default_url(version, scope)
  end

  defp build(definition, version, file_and_scope, options) do
    case Versioning.resolve_file_name(definition, version, file_and_scope) do
      nil -> nil
      _ ->
        definition.__storage.url(definition, version, file_and_scope, options)
    end
  end
end
