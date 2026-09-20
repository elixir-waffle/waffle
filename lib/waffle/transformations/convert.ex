defmodule Waffle.Transformations.Convert do
  @moduledoc false

  def apply(cmd, %Waffle.File{} = file, args, extension \\ nil) do
    new_path =
      if extension,
        do: Waffle.File.generate_temporary_path(extension),
        else: Waffle.File.generate_temporary_path(file)

    args =
      if is_function(args),
        do: args.(file.path, new_path),
        else: [file.path | String.split(args, " ") ++ [new_path]]

    program = to_string(cmd)

    ensure_executable_exists!(program)

    result = System.cmd(program, args_list(args), stderr_to_stdout: true)

    case result do
      {_, 0} ->
        if File.exists?(new_path) do
          {:ok, %Waffle.File{file | path: new_path, is_tempfile?: true}}
        else
          {:error, "Transform output file does not exist: #{new_path}"}
        end

      {error_message, _exit_code} ->
        {:error, error_message}
    end
  end

  defp args_list(args) when is_list(args), do: args
  defp args_list(args), do: ~w(#{args})

  defp ensure_executable_exists!(program) do
    unless System.find_executable(program) do
      raise Waffle.MissingExecutableError, message: program
    end
  end
end
