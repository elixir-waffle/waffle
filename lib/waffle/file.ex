defmodule Waffle.File do
  @moduledoc false

  alias Waffle.HTTPClient

  defstruct [:path, :file_name, :binary, :is_tempfile?, :stream]

  def generate_temporary_path(item \\ nil) do
    do_generate_temporary_path(item)
  end

  #
  # Handle a remote file
  #

  # Given a remote file
  # (respects content-disposition header)
  def new("http" <> _ = remote_path, definition) do
    uri = URI.parse(remote_path)
    filename = uri.path |> Path.basename() |> URI.decode()

    case save_file(uri, filename, definition) do
      {:ok, local_path, filename_from_content_disposition} ->
        %Waffle.File{
          path: local_path,
          file_name: filename_from_content_disposition,
          is_tempfile?: true
        }

      {:ok, local_path} ->
        %Waffle.File{path: local_path, file_name: filename, is_tempfile?: true}

      {:error, _reason} = err ->
        err

      :error ->
        {:error, :invalid_file_path}
    end
  end

  # Given a remote file with a filename
  def new(
        %{filename: filename, remote_path: remote_path} = %{filename: _, remote_path: "http" <> _},
        definition
      ) do
    uri = URI.parse(remote_path)

    case save_file(uri, filename, definition) do
      {:ok, local_path} ->
        %Waffle.File{path: local_path, file_name: filename, is_tempfile?: true}

      {:error, _reason} = err ->
        err

      :error ->
        {:error, :invalid_file_path}
    end
  end

  # Rejects invalid remote file path
  def new(
        %{filename: _filename, remote_path: _remote_path} = %{filename: _, remote_path: _},
        _definition
      ) do
    {:error, :invalid_file_path}
  end

  #
  # Handle a binary blob
  #

  def new(%{filename: filename, binary: binary}, _definition) do
    %Waffle.File{binary: binary, file_name: Path.basename(filename)}
    |> write_binary()
  end

  #
  # Handle a local file
  #

  # Accepts a path
  def new(path, _definition) when is_binary(path) do
    case File.exists?(path) do
      true -> %Waffle.File{path: path, file_name: Path.basename(path)}
      false -> {:error, :invalid_file_path}
    end
  end

  # Accepts a map conforming to %Plug.Upload{} syntax
  def new(%{filename: filename, path: path}, _definition) do
    case File.exists?(path) do
      true -> %Waffle.File{path: path, file_name: filename}
      false -> {:error, :invalid_file_path}
    end
  end

  #
  # Handle a stream
  #
  def new(%{filename: filename, stream: stream}, _definition) when is_struct(stream) do
    %Waffle.File{stream: stream, file_name: Path.basename(filename)}
  end

  #
  # Support functions
  #

  #
  #
  # Temp file with exact extension.
  # Used for converting formats when passing extension in transformations
  #

  defp do_generate_temporary_path(%Waffle.File{path: path}) do
    Path.extname(path || "")
    |> do_generate_temporary_path()
  end

  defp do_generate_temporary_path(extension) do
    ext = extension |> to_string()

    string_extension =
      cond do
        String.starts_with?(ext, ".") ->
          ext

        ext == "" ->
          ""

        true ->
          ".#{ext}"
      end

    file_name =
      :crypto.strong_rand_bytes(20)
      |> Base.encode32()
      |> Kernel.<>(string_extension)

    Path.join(tmp_dir(), file_name)
  end

  defp tmp_dir do
    case Application.get_env(:waffle, :tmp_dir) do
      nil -> System.tmp_dir()
      value -> value
    end
  end

  defp write_binary(file) do
    path = generate_temporary_path(file)
    File.write!(path, file.binary)

    %__MODULE__{
      file_name: file.file_name,
      path: path,
      is_tempfile?: true
    }
  end

  defp save_file(uri, filename, definition) do
    local_path =
      generate_temporary_path()
      |> Kernel.<>(Path.extname(filename))

    url = URI.to_string(uri)

    headers = definition.remote_file_headers(uri)

    case HTTPClient.Request.download(local_path, url, headers) do
      {:ok, filename} -> {:ok, local_path, filename}
      :ok -> {:ok, local_path}
      err -> err
    end
  end
end
