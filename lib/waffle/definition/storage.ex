defmodule Waffle.Definition.Storage do
  @moduledoc ~S"""
  Uploader configuration.

  Add `use Waffle.Definition` inside your module to use it as uploader.

  ## Storage directory

      config :waffle,
        storage_dir: "my/dir"

  The storage directory to place files. Defaults to `uploads`, but can
  be overwritten via configuration options `:storage_dir`

  The storage dir can also be overwritten on an individual basis, in
  each separate definition. A common pattern for user profile pictures
  is to store each user's uploaded images in a separate subdirectory
  based on their primary key:

      def storage_dir(version, {file, scope}) do
        "uploads/users/avatars/#{scope.id}"
      end


  > **Note**: If you are "attaching" a file to a record on creation (eg, while inserting the record at the same time), then you cannot use the model's `id` as a path component.  You must either (1) use a different storage path format, such as UUIDs, or (2) attach and update the model after an id has been given. [Read more about how to integrate it with Ecto](https://hexdocs.pm/waffle_ecto/filepath-with-id.html#content)

  > **Note**: The storage directory is used for both local filestorage (as the relative or absolute directory), and S3 storage, as the path name (not including the bucket).


  ## Asynchronous File Uploading

  If you specify multiple versions in your definition module, each
  version is processed and stored concurrently as independent Tasks.
  To prevent an overconsumption of system resources, each Task is
  given a specified timeout to wait, after which the process will
  fail.  By default this is `15 seconds`.

  If you wish to change the time allocated to version transformation
  and storage, you may add a configuration parameter:

      config :waffle,
        :version_timeout, 15_000 # milliseconds

  To disable asynchronous processing, add `@async false` to your
  upload definition.

  ## Storage of files

  Waffle currently supports

    * `Waffle.Storage.S3`
    * `Waffle.Storage.Local`

  Override the `__storage` function in your definition module if you
  want to use a different type of storage for a particular uploader.

  ## File Validation

  While storing files on S3 (rather than your harddrive) eliminates
  some malicious attack vectors, it is strongly encouraged to validate
  the extensions of uploaded files as well.

  Waffle delegates validation to a `validate/1` function with a tuple
  of the file and scope.  As an example, to validate that an uploaded
  file conforms to popular image formats, you may use:

      defmodule Avatar do
        use Waffle.Definition
        @extension_whitelist ~w(.jpg .jpeg .gif .png)

        def validate({file, _}) do
          file_extension = file.file_name |> Path.extname() |> String.downcase()
          Enum.member?(@extension_whitelist, file_extension)
        end
      end

  Any uploaded file failing validation will return `{:error,
  :invalid_file}` when passed through to `Avatar.store`.


  """
  defmacro __using__(_) do
    quote do
      @acl :private
      @async true

      def bucket, do: Application.fetch_env!(:waffle, :bucket)
      def asset_host, do: Application.get_env(:waffle, :asset_host)
      def filename(_, {file, _}), do: Path.basename(file.file_name, Path.extname(file.file_name))
      def storage_dir_prefix, do: Application.get_env(:waffle, :storage_dir_prefix, "")
      def storage_dir(_, _), do: Application.get_env(:waffle, :storage_dir, "uploads")
      def validate(_), do: true
      def default_url(version, _), do: default_url(version)
      def default_url(_), do: nil
      def __storage, do: Application.get_env(:waffle, :storage, Waffle.Storage.S3)

      defoverridable storage_dir_prefix: 0,
                     storage_dir: 2,
                     filename: 2,
                     validate: 1,
                     default_url: 1,
                     default_url: 2,
                     __storage: 0,
                     bucket: 0,
                     asset_host: 0

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
