defmodule Waffle.Transformations.Command do
  @doc """
  Execute a System.cmd command.
  """
  @spec execute(String.t() | atom, list) :: tuple
  def execute(program, args) when is_atom(program),
    do: execute(to_string(program), args)

  def execute(program, args) when is_list(args) do
    ensure_executable_exists!(program)
    System.cmd(program, args, stderr_to_stdout: true)
  end

  @doc """
  Checks if the given program exists in the system, if it doesn't an error will be raised.
  """
  @spec ensure_executable_exists!(String.t()) :: no_return
  def ensure_executable_exists!(program) do
    unless System.find_executable(program) do
      raise Waffle.MissingExecutableError, message: program
    end
  end
end
