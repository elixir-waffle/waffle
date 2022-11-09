defmodule Waffle.Actions.Delete do
  @moduledoc ~S"""
  Delete files from a defined adapter.

  After an object is stored through Waffle, you may optionally remove
  it.  To remove a stored object, pass the same path identifier and
  scope from which you stored the object.

      # Without a scope:
      {:ok, original_filename} = Avatar.store("/Images/me.png")
      :ok = Avatar.delete(original_filename)

      # With a scope:
      user = Repo.get!(User, 1)
      {:ok, original_filename} = Avatar.store({"/Images/me.png", user})
      # example 1
      :ok = Avatar.delete({original_filename, user})
      # example 2
      user = Repo.get!(User, 1)
      :ok = Avatar.delete({user.avatar, user})

  """

  alias Waffle.Actions.Delete

  defmacro __using__(_) do
    quote do
      def delete(args), do: Delete.delete(__MODULE__, args)

      defoverridable [{:delete, 1}]
    end
  end

  def delete(definition, {filepath, scope}) when is_binary(filepath) do
    do_delete(definition, {%{file_name: filepath}, scope})
  end

  def delete(definition, filepath) when is_binary(filepath) do
    do_delete(definition, {%{file_name: filepath}, nil})
  end

  #
  # Private
  #

  defp version_timeout do
    Application.get_env(:waffle, :version_timeout) || 15_000
  end

  defp do_delete(definition, {file, scope}) do
    results =
      if definition.async do
        definition.__versions
        |> Enum.map(fn version -> async_delete_version(definition, version, {file, scope}) end)
        |> Enum.reduce([], fn task, results ->
          results ++ [Task.await(task, version_timeout())]
        end)
      else
        definition.__versions
        |> Enum.reduce([], fn version, results ->
          results ++ [delete_version(definition, version, {file, scope})]
        end)
      end

    if Enum.all?(results, &match?(:ok, &1)) do
      :ok
    else
      errors =
        results
        |> Enum.reject(&match?(:ok, &1))
        |> Enum.reduce([], &(&2 ++ [&1]))

      {:error, errors}
    end
  end

  defp async_delete_version(definition, version, {file, scope}) do
    Task.async(fn -> delete_version(definition, version, {file, scope}) end)
  end

  defp delete_version(definition, version, {file, scope}) do
    conversion = definition.transform(version, {file, scope})

    if conversion == :skip do
      :ok
    else
      definition
      |> definition.__storage.delete(version, {file, scope})
      |> format_result(version)
    end
  end

  defp format_result(response, version) do
    case response do
      {:error, reason} -> {version, reason}
      :error -> {version, :unknown}
      _ -> :ok
    end
  end
end
