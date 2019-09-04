defmodule Waffle.Definition.Storage do
  defmacro __using__(_) do
    quote do
      @acl :private
      @async true

      def bucket, do: Application.fetch_env!(:waffle, :bucket)
      def asset_host, do: Application.get_env(:waffle, :asset_host)
      def filename(_, {file, _}), do: Path.basename(file.file_name, Path.extname(file.file_name))
      def storage_dir_prefix(), do: Application.get_env(:waffle, :storage_dir_prefix, "")
      def storage_dir(_, _), do: Application.get_env(:waffle, :storage_dir, "uploads")
      def validate(_), do: true
      def default_url(version, _), do: default_url(version)
      def default_url(_), do: nil
      def __storage, do: Application.get_env(:waffle, :storage, Waffle.Storage.S3)

      defoverridable [storage_dir_prefix: 0, storage_dir: 2, filename: 2, validate: 1, default_url: 1, default_url: 2, __storage: 0, bucket: 0, asset_host: 0]

      @before_compile Waffle.Definition.Storage
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def acl(_, _), do: @acl
      def s3_object_headers(_, _), do: []
      def async, do: @async
    end
  end
end
