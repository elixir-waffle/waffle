defmodule Waffle.Actions.Store do
  @moduledoc ~S"""
  Store files to a defined adapter.

  The definition module responds to `Avatar.store/1` which
  accepts either:

    * A path to a local file

    * A path to a remote `http` or `https` file

    * A map with a filename and path keys (eg, a `%Plug.Upload{}`)

    * A map with a filename and binary keys (eg, `%{filename: "image.png", binary: <<255,255,255,...>>}`)

    * A two-element tuple consisting of one of the above file formats as well as a scope map

  Example usage as general file store:

      # Store any locally accessible file
      Avatar.store("/path/to/my/file.png") #=> {:ok, "file.png"}

      # Store any remotely accessible file
      Avatar.store("http://example.com/file.png") #=> {:ok, "file.png"}

      # Store a file directly from a `%Plug.Upload{}`
      Avatar.store(%Plug.Upload{filename: "file.png", path: "/a/b/c"}) #=> {:ok, "file.png"}

      # Store a file from a connection body
      {:ok, data, _conn} = Plug.Conn.read_body(conn)
      Avatar.store(%{filename: "file.png", binary: data})

  Example usage as a file attached to a `scope`:

      scope = Repo.get(User, 1)
      Avatar.store({%Plug.Upload{}, scope}) #=> {:ok, "file.png"}

  This scope will be available throughout the definition module to be
  used as an input to the storage parameters (eg, store files in
  `/uploads/#{scope.id}`).

  """

  alias Waffle.Actions.Store
  alias Waffle.Definition.Versioning

  defmacro __using__(_) do
    quote do
      def store(args), do: Store.store(__MODULE__, args)
    end
  end

  def store(definition, {file, scope}) when is_binary(file) or is_map(file) do
    put(definition, {Waffle.File.new(file, definition), scope})
  end

  def store(definition, filepath) when is_binary(filepath) or is_map(filepath) do
    store(definition, {filepath, nil})
  end

  #
  # Private
  #

  defp put(_definition, {error = {:error, _msg}, _scope}), do: error

  defp put(definition, {%Waffle.File{} = file, scope}) do
    case definition.validate({file, scope}) do
      result when result == true or result == :ok ->
        put_versions(definition, {file, scope})
        |> cleanup!(file)

      {:error, message} ->
        {:error, message}

      _ ->
        {:error, :invalid_file}
    end
  end

  defp put_versions(definition, {file, scope}) do
    if definition.async do
      definition.__versions
      |> Enum.map(fn(r)    -> async_process_version(definition, r, {file, scope}) end)
      |> Enum.map(fn(task) -> Task.await(task, version_timeout()) end)
      |> ensure_all_success
      |> Enum.map(fn({v, r})    -> async_put_version(definition, v, {r, scope}) end)
      |> Enum.map(fn(task) -> Task.await(task, version_timeout()) end)
      |> handle_responses(file.file_name)
    else
      definition.__versions
      |> Enum.map(fn(version) -> process_version(definition, version, {file, scope}) end)
      |> ensure_all_success
      |> Enum.map(fn({version, result}) -> put_version(definition, version, {result, scope}) end)
      |> handle_responses(file.file_name)
    end
  end

  defp ensure_all_success(responses) do
    errors = Enum.filter(responses, fn({_version, resp}) -> elem(resp, 0) == :error end)
    if Enum.empty?(errors), do: responses, else: errors
  end

  defp handle_responses(responses, filename) do
    errors = Enum.filter(responses, fn(resp) -> elem(resp, 0) == :error end) |> Enum.map(fn(err) -> elem(err, 1) end)
    if Enum.empty?(errors), do: {:ok, filename}, else: {:error, errors}
  end

  defp version_timeout do
    Application.get_env(:waffle, :version_timeout) || 15_000
  end

  defp async_process_version(definition, version, {file, scope}) do
    Task.async(fn ->
      process_version(definition, version, {file, scope})
    end)
  end

  defp async_put_version(definition, version, {result, scope}) do
    Task.async(fn ->
      put_version(definition, version, {result, scope})
    end)
  end

  defp process_version(definition, version, {file, scope}) do
    {version, Waffle.Processor.process(definition, version, {file, scope})}
  end

  defp put_version(definition, version, {result, scope}) do
    case result do
      {:error, error} -> {:error, error}
      {:ok, nil} -> {:ok, nil}
      {:ok, file} ->
        file_name = Versioning.resolve_file_name(definition, version, {file, scope})
        file      = %Waffle.File{file | file_name: file_name}
        result    = definition.__storage.put(definition, version, {file, scope})

        case definition.transform(version, {file, scope}) do
          :noaction ->
            # We don't have to cleanup after `:noaction` transformations
            # because final `cleanup!` will remove the original temporary file.
            result
          _ ->
            cleanup!(result, file)
        end
    end
  end

  defp cleanup!(result, file) do
    # If we were working with binary data or a remote file, a tempfile was
    # created that we need to clean up.
    if file.is_tempfile? do
      File.rm!(file.path)
    end

    result
  end

end
