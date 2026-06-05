defmodule Waffle.File do
  @moduledoc false

  defstruct [:path, :file_name, :binary, :is_tempfile?, :stream]

  def generate_temporary_path(item \\ nil) do
    do_generate_temporary_path(item)
  end

  #
  # Handle a remote file
  #

  # Given a remote file
  # (respects content-disposition header)
  def new(remote_path = "http" <> _, definition) do
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

    case save_temp_file(local_path, uri, definition) do
      {:ok, filename} -> {:ok, local_path, filename}
      :ok -> {:ok, local_path}
      err -> err
    end
  end

  defp save_temp_file(local_path, remote_path, definition) do
    remote_file = get_remote_path(remote_path, definition)

    case remote_file do
      {:ok, body, filename} ->
        case File.write(local_path, body) do
          :ok -> {:ok, filename}
          _ -> :error
        end

      {:ok, body} ->
        File.write(local_path, body)

      {:error, _reason} = err ->
        err
    end
  end

  # hackney :connect_timeout - timeout used when establishing a connection, in milliseconds
  # hackney :recv_timeout - timeout used when receiving from a connection, in milliseconds
  # hackney :max_body_length - maximum size of the file to download, in bytes. Defaults to :infinity
  # :backoff_max - maximum backoff time, in milliseconds
  # :backoff_factor - a backoff factor to apply between attempts, in milliseconds
  defp get_remote_path(remote_path, definition) do
    headers = definition.remote_file_headers(remote_path)

    options = [
      follow_redirect: true,
      recv_timeout: Application.get_env(:waffle, :recv_timeout, 5_000),
      connect_timeout: Application.get_env(:waffle, :connect_timeout, 10_000),
      max_retries: Application.get_env(:waffle, :max_retries, 3),
      backoff_factor: Application.get_env(:waffle, :backoff_factor, 1000),
      backoff_max: Application.get_env(:waffle, :backoff_max, 30_000)
    ]

    request(remote_path, headers, options)
  end

  defp request(remote_path, headers, options, tries \\ 0) do
    recv_timeout = Keyword.get(options, :recv_timeout, 5_000)

    # hackney 4.x recv_timeout is only enforced for HTTP/1.1 socket reads; it has
    # no effect on HTTP/2 connections (which receive data via async Erlang messages).
    # Wrapping with Task.yield gives a protocol-agnostic timeout.
    task = Task.async(fn ->
      :hackney.get(URI.to_string(remote_path), headers, "", options)
    end)

    hackney_result =
      case Task.yield(task, recv_timeout) do
        {:ok, result} -> result
        nil ->
          Task.shutdown(task, :brutal_kill)
          {:error, :timeout}
      end

    case hackney_result do
      {:ok, 200, response_headers, body} ->
        max_body_length = Application.get_env(:waffle, :max_body_length, :infinity)

        if max_body_length != :infinity and byte_size(body) > max_body_length do
          {:error, :body_too_large}
        else
          headers_obj = :hackney_headers.new(response_headers)
          filename = content_disposition(headers_obj)

          if is_nil(filename) do
            {:ok, body}
          else
            {:ok, body, filename}
          end
        end

      {:error, %{reason: :timeout}} ->
        case retry(tries, options) do
          {:ok, :retry} -> request(remote_path, headers, options, tries + 1)
          {:error, :out_of_tries} -> {:error, :timeout}
        end

      {:error, :timeout} ->
        case retry(tries, options) do
          {:ok, :retry} -> request(remote_path, headers, options, tries + 1)
          {:error, :out_of_tries} -> {:error, :recv_timeout}
        end

      {:ok, 503, _headers, _body} = response ->
        case retry(tries, options) do
          {:ok, :retry} ->
            request(remote_path, headers, options, tries + 1)

          {:error, :out_of_tries} ->
            {:error, {:waffle_hackney_error, response}}
        end

      {:ok, _, _, _} = response ->
        {:error, {:waffle_hackney_error, response}}

      _err ->
        {:error, :waffle_hackney_error}
    end
  end

  defp content_disposition(headers) do
    case :hackney_headers.get_value("content-disposition", headers) do
      :undefined ->
        nil

      value ->
        parse_content_disposition_filename(value)
    end
  end

  @doc false
  def parse_content_disposition_filename(value) do
    case Regex.run(~r/filename="([^"]+)"/i, value) do
      [_, filename] when filename != "" ->
        filename

      _ ->
        case Regex.run(~r/filename=([^";\s][^;\s]*)/i, value) do
          [_, filename] when filename != "" -> filename
          _ -> nil
        end
    end
  end

  defp retry(tries, options) do
    if tries < options[:max_retries] do
      backoff = round(options[:backoff_factor] * :math.pow(2, tries - 1))
      backoff = :erlang.min(backoff, options[:backoff_max])
      :timer.sleep(backoff)
      {:ok, :retry}
    else
      {:error, :out_of_tries}
    end
  end
end
