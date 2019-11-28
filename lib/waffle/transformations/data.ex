defmodule Waffle.Transformations.Data do
  alias Waffle.Transformations.Command

  @doc """
  Get the data of a file located at the given path.
  """
  @spec get_file_data(atom, String.t()) :: no_return
  def get_file_data(ext, filepath) when ext in [:jpg, :png, :gif] do
    Map.merge(identify_sizes_imagick(filepath), identify_color_imagick(filepath))
  end

  def get_file_data(ext, filepath) when ext === :mp4 do
    identify_sizes_ffmpeg(filepath)
  end

  def get_file_data(_), do: %{}

  #
  # Private functions to get our file data.
  #

  @ffprobe_cmd_args ~w(-v error -show_entries format=size -show_entries stream=width,height -of default=noprint_wrappers=1)
  defp identify_sizes_ffmpeg(filepath) do
    with {output, 0} <- Command.execute("ffprobe", [filepath | @ffprobe_cmd_args]) do
      [_, w] = Regex.run(~r/width=(\d+)/u, output)
      [_, h] = Regex.run(~r/height=(\d+)/u, output)
      [_, size] = Regex.run(~r/size=(\d+)/u, output)

      %{
        width: String.to_integer(w),
        height: String.to_integer(h),
        size: String.to_integer(size)
      }
    else
      _ -> %{}
    end
  end

  defp identify_sizes_imagick(filepath) do
    with {output, 0} <- Command.execute("identify", ["-precision", "10", filepath]) do
      [_, w, h] = Regex.run(~r/(\d+)x(\d+)/u, output)
      [_, size] = Regex.run(~r/(\d+)B/u, output)

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
  defp identify_color_imagick(filepath) do
    with {output, 0} <- Command.execute("convert", [filepath | @identify_color_cmd_args]) do
      [color] = Regex.run(~r/#[[:xdigit:]]{6}/, output)

      %{color: color}
    else
      _ -> %{}
    end
  end
end
