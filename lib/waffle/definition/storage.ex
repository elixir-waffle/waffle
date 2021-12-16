defmodule Waffle.Definition.Storage do
  @moduledoc ~S"""
  Uploader configuration.

  Add `use Waffle.Definition` inside your module to use it as uploader.

  ## Storage directory

  By default, the storage directory is `uploads`. But, it can be customized
  in two ways.

  ### By setting up configuration

  Customize storage directory via configuration option `:storage_dir`.

      config :waffle,
        storage_dir: "my/dir"

  ### By overriding the relevent functions in definition modules

  Every definition module has a default `storage_dir/2` which is overridable.

  For example, a common pattern for user avatars is to store each user's
  uploaded images in a separate subdirectory based on primary key:

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
  fail.  By default, the timeout is `15_000` milliseconds.

  If you wish to change the time allocated to version transformation
  and storage, you can add a configuration option:

      config :waffle,
        :version_timeout, 15_000 # milliseconds

  To disable asynchronous processing, add `@async false` to your
  definition module.

  ## Storage of files

  Waffle currently supports:

    * `Waffle.Storage.Local`
    * `Waffle.Storage.S3`

  Override the `__storage` function in your definition module if you
  want to use a different type of storage for a particular uploader.

  ## File Validation

  While storing files on S3 eliminates some malicious attack vectors,
  it is strongly encouraged to validate the extensions of uploaded
  files as well.

  Waffle delegates validation to a `validate/1` function with a tuple
  of the file and scope.  As an example, in order to validate that an
  uploaded file conforms to popular image formats, you can use:

      defmodule Avatar do
        use Waffle.Definition
        @extension_whitelist ~w(.jpg .jpeg .gif .png)

        def validate({file, _}) do
          file_extension = file.file_name |> Path.extname() |> String.downcase()

          case Enum.member?(@extension_whitelist, file_extension) do
            true -> :ok
            false -> {:error, "invalid file type"}
          end
        end
      end

  Validation will be considered successful if the function returns `true` or `:ok`.
  A customized error message can be returned in the form of `{:error, message}`.
  Any other return value will return `{:error, :invalid_file}` when passed through
  to `Avatar.store`.

  ## Passing custom headers when downloading from remote path

  By default, when downloading files from remote path request headers are empty,
  but if you wish to provide your own, you can override the `remote_file_headers/1`
  function in your definition module. For example:

      defmodule Avatar do
        use Waffle.Definition

        def remote_file_headers(%URI{host: "elixir-lang.org"}) do
          credentials = Application.get_env(:my_app, :avatar_credentials)
          token = Base.encode64(credentials[:username] <> ":" <> credentials[:password])

          [{"Authorization", "Basic #{token}")}]
        end
      end

  This code would authenticate request only for specific domain. Otherwise, it would send
  empty request headers.

  """
  defmacro __using__(_) do
    quote do
      @acl :private
      @async true

      def bucket, do: Application.fetch_env!(:waffle, :bucket)
      def bucket({_file, _scope}), do: bucket()
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
                     bucket: 1,
                     asset_host: 0

      @before_compile Waffle.Definition.Storage
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def acl(_, _), do: @acl
      def s3_object_headers(_, _), do: []
      def async, do: @async
      def remote_file_headers(_), do: []
    end
  end
end
