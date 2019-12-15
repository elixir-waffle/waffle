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
    if definition.async do
      definition.__versions
      |> Enum.map(fn(r)     -> async_delete_version(definition, r, {file, scope}) end)
      |> Enum.each(fn(task) -> Task.await(task, version_timeout()) end)
    else
      definition.__versions
      |> Enum.each(fn(version) -> delete_version(definition, version, {file, scope}) end)
    end
    :ok
  end

  defp async_delete_version(definition, version, {file, scope}) do
    Task.async(fn -> delete_version(definition, version, {file, scope}) end)
  end

  defp delete_version(definition, version, {file, scope}) do
    conversion = definition.transform(version, {file, scope})
    if conversion == :skip do
      :ok
    else
      definition.__storage.delete(definition, version, {file, scope})
    end
  end
end
