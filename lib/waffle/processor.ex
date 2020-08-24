defmodule Waffle.Processor do
  @moduledoc ~S"""
  Apply transformation to files.

  Waffle can be used to facilitate transformations of uploaded files
  via any system executable.  Some common operations you may want to
  take on uploaded files include resizing an uploaded avatar with
  ImageMagick or extracting a still image from a video with FFmpeg.

  To transform an image, the definition module must define a
  `transform/2` function which accepts a version atom and a tuple
  consisting of the uploaded file and corresponding scope.

  This transform handler accepts the version atom, as well as the
  file/scope argument, and is responsible for returning one of the
  following:

    * `:noaction` - The original file will be stored as-is.

    * `:skip` - Nothing will be stored for the provided version.

    * `{executable, args}` - The `executable` will be called with
      `System.cmd` with the format
      `#{original_file_path} #{args} #{transformed_file_path}`.

    * `{executable, fn(input, output) -> args end}` If your executable
      expects arguments in a format other than the above, you may
      supply a function to the conversion tuple which will be invoked
      to generate the arguments. The arguments can be returned as a
      string (e.g. – `" #{input} -strip -thumbnail 10x10 #{output}"`)
      or a list (e.g. – `[input, "-strip", "-thumbnail", "10x10",
      output]`) for even more control.

    * `{executable, args, output_extension}` - If your transformation
      changes the file extension (eg, converting to `png`), then the
      new file extension must be explicit.

  ## ImageMagick transformations

  As images are one of the most commonly uploaded filetypes, Waffle
  has a recommended integration with ImageMagick's `convert` tool for
  manipulation of images.  Each definition module may specify as many
  versions as desired, along with the corresponding transformation for
  each version.

  The expected return value of a `transform` function call must either
  be `:noaction`, in which case the original file will be stored
  as-is, `:skip`, in which case nothing will be stored, or `{:convert,
  transformation}` in which the original file will be processed via
  ImageMagick's `convert` tool with the corresponding transformation
  parameters.

  The following example stores the original file, as well as a squared
  100x100 thumbnail version which is stripped of comments (eg, GPS
  coordinates):

      defmodule Avatar do
        use Waffle.Definition

        @versions [:original, :thumb]

        def transform(:thumb, _) do
          {:convert, "-strip -thumbnail 100x100^ -gravity center -extent 100x100"}
        end
      end

  Other examples:

      # Change the file extension through ImageMagick's `format` parameter:
      {:convert, "-strip -thumbnail 100x100^ -gravity center -extent 100x100 -format png", :png}

      # Take the first frame of a gif and process it into a square jpg:
      {:convert, fn(input, output) -> "#{input}[0] -strip -thumbnail 100x100^ -gravity center -extent 100x100 -format jpg #{output}", :jpg}

  For more information on defining your transformation, please consult
  [ImageMagick's convert
  documentation](http://www.imagemagick.org/script/convert.php).

  > **Note**: Keep this transformation function simple and deterministic based on the version, file name, and scope object. The `transform` function is subsequently called during URL generation, and the transformation is scanned for the output file format.  As such, if you conditionally format the image as a `png` or `jpg` depending on the time of day, you will be displeased with the result of Waffle's URL generation.

  > **System Resources**: If you are accepting arbitrary uploads on a public site, it may be prudent to add system resource limits to prevent overloading your system resources from malicious or nefarious files.  Since all processing is done directly in ImageMagick, you may pass in system resource restrictions through the [-limit](http://www.imagemagick.org/script/command-line-options.php#limit) flag.  One such example might be: `-limit area 10MB -limit disk 100MB`.

  ## FFmpeg transformations

  Common transformations of uploaded videos can be also defined
  through your definition module:

      # To take a thumbnail from a video:
      {:ffmpeg, fn(input, output) -> "-i #{input} -f jpg #{output}" end, :jpg}

      # To convert a video to an animated gif
      {:ffmpeg, fn(input, output) -> "-i #{input} -f gif #{output}" end, :gif}

  ## Complex Transformations

  `Waffle` requires the output of your transformation to be located at
  a predetermined path.  However, the transformation may be done
  completely outside of `Waffle`. For fine-grained transformations,
  you should create an executable wrapper in your $PATH (eg. bash
  script) which takes these proper arguments, runs your
  transformation, and then moves the file into the correct location.

  For example, to use `soffice` to convert a doc to an html file, you
  should place the following bash script in your $PATH:

      #!/usr/bin/env sh

      # `soffice` doesn't allow for output file path option, and waffle can't find the
      # temporary file to process and copy. This script has a similar argument list as
      # what waffle expects. See https://github.com/stavro/arc/issues/77.

      set -e
      set -o pipefail

      function convert {
          soffice \
              --headless \
              --convert-to html \
              --outdir $TMPDIR \
              "$1"
      }

      function filter_new_file_name {
          awk -F$TMPDIR '{print $2}' \
          | awk -F" " '{print $1}' \
          | awk -F/ '{print $2}'
      }

      converted_file_name=$(convert "$1" | filter_new_file_name)

      cp $TMPDIR/$converted_file_name "$2"
      rm $TMPDIR/$converted_file_name

  And perform the transformation as such:

      def transform(:html, _) do
        {:soffice_wrapper, fn(input, output) -> [input, output] end, :html}
      end

  """
  alias Waffle.Transformations.Convert

  def process(definition, version, {file, scope}) do
    transform = definition.transform(version, {file, scope})
    apply_transformation(file, transform)
  end

  defp apply_transformation(_, :skip), do: {:ok, nil}
  defp apply_transformation(file, :noaction), do: {:ok, file}
  # Deprecated
  defp apply_transformation(file, {:noaction}), do: {:ok, file}

  defp apply_transformation(file, {cmd, conversion}) do
    Convert.apply(cmd, file, conversion)
  end

  defp apply_transformation(file, {cmd, conversion, extension}) do
    Convert.apply(cmd, file, conversion, extension)
  end
end
