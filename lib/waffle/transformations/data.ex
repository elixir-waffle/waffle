defmodule Waffle.Transformations.Data do
  alias Waffle.Transformations.Command

  @doc """
  Get the data of a file located at the given path.
  """
  @spec get_file_data(atom, String.t()) :: no_return
  def get_file_data(ext, filepath) when ext in [:jpg, :png, :gif] do
    Map.merge(identify_sizes(filepath), identify_color(filepath))
  end

  def get_file_data(_), do: %{}

  defp identify_sizes(filepath) do
    with {output, 0} <- Command.execute("identify", [filepath]) do
      data = String.split(output)

      [_, w, h] = Regex.run(~r/(\d+)x(\d+)/u, Enum.fetch!(data, 2))
      [_, size] = Regex.run(~r/(\d+)B/u, Enum.fetch!(data, 7))

      %{
        width: String.to_integer(w),
        height: String.to_integer(h),
        size: String.to_integer(size)
      }
    else
      _ -> %{}
    end
  end

  @identify_color_cmd_args ~w(-gravity center -crop 85% -resize 1x1\! -depth 8 txt:-)
  defp identify_color(filepath) do
    with {output, 0} <- Command.execute("convert", [filepath | @identify_color_cmd_args]) do
      [color] = Regex.run(~r/#[[:xdigit:]]{6}/, output)

      %{color: color}
    else
      _ -> %{}
    end
  end
end
