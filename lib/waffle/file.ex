defmodule Waffle.File do
  @moduledoc false

  defstruct [:path, :file_name, :binary, :is_tempfile?]

  def generate_temporary_path(file \\ nil) do
    extension = Path.extname((file && file.path) || "")

    file_name =
      :crypto.strong_rand_bytes(20)
      |> Base.encode32()
      |> Kernel.<>(extension)

    Path.join(System.tmp_dir(), file_name)
  end

  #
  # Handle a remote file
  #

  # Given a remote file
  def new(remote_path = "http" <> _) do
    uri = URI.parse(remote_path)

    filename =
      case uri.path do
        v when v == nil or v == "/" ->
          "download"

        path ->
          Path.basename(path) |> URI.decode()
      end

    case save_file(uri, filename) do
      {:ok, local_path} -> %Waffle.File{path: local_path, file_name: filename, is_tempfile?: true}
      :error -> {:error, :invalid_file_path}
    end
  end

  # Given a remote file with a filename
  def new(
        %{filename: filename, remote_path: remote_path} = %{filename: _, remote_path: "http" <> _}
      ) do
    uri = URI.parse(remote_path)

    case save_file(uri, filename) do
      {:ok, local_path} -> %Waffle.File{path: local_path, file_name: filename, is_tempfile?: true}
      :error -> {:error, :invalid_file_path}
    end
  end

  # Rejects invalid remote file path
  def new(%{filename: _filename, remote_path: _remote_path} = %{filename: _, remote_path: _}) do
    {:error, :invalid_file_path}
  end

  #
  # Handle a binary blob
  #

  def new(%{filename: filename, binary: binary}) do
    %Waffle.File{binary: binary, file_name: Path.basename(filename)}
    |> write_binary()
  end

  #
  # Handle a local file
  #

  # Accepts a path
  def new(path) when is_binary(path) do
    case File.exists?(path) do
      true -> %Waffle.File{path: path, file_name: Path.basename(path)}
      false -> {:error, :invalid_file_path}
    end
  end

  # Accepts a map conforming to %Plug.Upload{} syntax
  def new(%{filename: filename, path: path}) do
    case File.exists?(path) do
      true -> %Waffle.File{path: path, file_name: filename}
      false -> {:error, :invalid_file_path}
    end
  end

  #
  # Support functions
  #

  defp write_binary(file) do
    path = generate_temporary_path(file)
    File.write!(path, file.binary)

    %__MODULE__{
      file_name: file.file_name,
      path: path,
      is_tempfile?: true
    }
  end

  defp save_file(uri, filename) do
    local_path =
      generate_temporary_path()
      |> Kernel.<>(Path.extname(filename))

    case save_temp_file(local_path, uri) do
      :ok -> {:ok, local_path}
      _ -> :error
    end
  end

  defp save_temp_file(local_path, remote_path) do
    remote_file = get_remote_path(remote_path)

    case remote_file do
      {:ok, body} -> File.write(local_path, body)
      {:error, error} -> {:error, error}
    end
  end

  # hackney :connect_timeout - timeout used when establishing a connection, in milliseconds
  # hackney :recv_timeout - timeout used when receiving from a connection, in milliseconds
  # :backoff_max - maximum backoff time, in milliseconds
  # :backoff_factor - a backoff factor to apply between attempts, in milliseconds
  defp get_remote_path(remote_path) do
    options = [
      follow_redirect: true,
      recv_timeout: Application.get_env(:waffle, :recv_timeout, 5_000),
      connect_timeout: Application.get_env(:waffle, :connect_timeout, 10_000),
      max_retries: Application.get_env(:waffle, :max_retries, 3),
      backoff_factor: Application.get_env(:waffle, :backoff_factor, 1000),
      backoff_max: Application.get_env(:waffle, :backoff_max, 30_000)
    ]

    request(remote_path, options)
  end

  defp request(remote_path, options, tries \\ 0) do
    case :hackney.get(URI.to_string(remote_path), [], "", options) do
      {:ok, 200, _headers, client_ref} ->
        :hackney.body(client_ref)

      {:error, %{reason: :timeout}} ->
        case retry(tries, options) do
          {:ok, :retry} -> request(remote_path, options, tries + 1)
          {:error, :out_of_tries} -> {:error, :timeout}
        end

      _ ->
        {:error, :waffle_hackney_error}
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
