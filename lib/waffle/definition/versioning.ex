defmodule Waffle.Definition.Versioning do
  @moduledoc ~S"""
  Define proper name for a version.

  It may be undesirable to retain original filenames (eg, it may
  contain personally identifiable information, vulgarity,
  vulnerabilities with Unicode characters, etc).

  You may specify the destination filename for uploaded versions
  through your definition module.

  A common pattern is to combine directories scoped to a particular
  model's primary key, along with static filenames. (eg:
  `user_avatars/1/thumb.png`).

      # To retain the original filename, but prefix the version and user id:
      def filename(version, {file, scope}) do
        file_name = Path.basename(file.file_name, Path.extname(file.file_name))
        "#{scope.id}_#{version}_#{file_name}"
      end

      # To make the destination file the same as the version:
      def filename(version, _), do: version

  """

  defmacro __using__(_) do
    quote do
      @versions [:original]
      @before_compile Waffle.Definition.Versioning
    end
  end

  def resolve_file_name(definition, version, {file, scope}) do
    name = definition.filename(version, {file, scope})
    conversion = definition.transform(version, {file, scope})

    case conversion do
      :skip       -> nil
      {_, _, ext} -> "#{name}.#{ext}"
       _          -> "#{name}#{Path.extname(file.file_name)}"
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def transform(_, _), do: :noaction
      def __versions, do: @versions
    end
  end
end
