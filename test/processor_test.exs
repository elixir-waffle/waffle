defmodule WaffleTest.Processor do
  use ExUnit.Case, async: false
  @img "test/support/image.png"
  @img2 "test/support/image two.png"

  defmodule DummyDefinition do
    use Waffle.Actions.Store
    use Waffle.Definition.Storage

    alias Waffle.Transformations.Convert

    def validate({file, _}), do: String.ends_with?(file.file_name, ".png")
    def transform(:original, _), do: :noaction
    def transform(:thumb, _), do: {:convert, "-strip -thumbnail 10x10"}

    def transform(:med, _),
      do: {:convert, fn input, output -> " #{input} -strip -thumbnail 10x10 #{output}" end, :jpg}

    def transform(:small, _),
      do:
        {:convert, fn input, output -> [input, "-strip", "-thumbnail", "10x10", output] end, :jpg}

    def transform(:custom, _) do
      fn _version, file ->
        Convert.apply(
          :convert,
          file,
          fn input, output -> [input, "-strip", "-thumbnail", "1x1", output] end,
          :jpg
        )
      end
    end

    def transform(:custom_with_ext, _) do
      {&transform_custom/2, &transform_custom_ext/2}
    end

    def transform(:skipped, _), do: :skip

    defp transform_custom(version, file) do
      Convert.apply(
        :convert,
        file,
        fn input, output -> [input, "-strip", "-thumbnail", "1x1", output] end,
        transform_custom_ext(version, file)
      )
    end

    defp transform_custom_ext(_, _), do: :jpg

    def __versions, do: [:original, :thumb]
  end

  defmodule BrokenDefinition do
    use Waffle.Actions.Store
    use Waffle.Definition.Storage

    def validate({file, _}), do: String.ends_with?(file.file_name, ".png")
    def transform(:original, _), do: :noaction
    def transform(:thumb, _), do: {:convert, "-strip -invalidTransformation 10x10"}
    def __versions, do: [:original, :thumb]
  end

  defmodule MissingExecutableDefinition do
    use Waffle.Definition

    def transform(:original, _), do: {:blah, ""}
  end

  test "returns the original path for :noaction transformations" do
    {:ok, file} =
      Waffle.Processor.process(
        DummyDefinition,
        :original,
        {Waffle.File.new(@img, DummyDefinition), nil}
      )

    assert file.path == @img
  end

  test "returns nil for :skip transformations" do
    assert {:ok, nil} =
             Waffle.Processor.process(
               DummyDefinition,
               :skipped,
               {Waffle.File.new(@img, DummyDefinition), nil}
             )
  end

  test "transforms a copied version of file according to the specified transformation" do
    {:ok, new_file} =
      Waffle.Processor.process(
        DummyDefinition,
        :thumb,
        {Waffle.File.new(@img, DummyDefinition), nil}
      )

    assert new_file.path != @img
    # original file untouched
    assert "128x128" == geometry(@img)
    assert "10x10" == geometry(new_file.path)
    cleanup(new_file.path)
  end

  test "transforms a copied version of file according to a function transformation that returns a string" do
    {:ok, new_file} =
      Waffle.Processor.process(
        DummyDefinition,
        :med,
        {Waffle.File.new(@img, DummyDefinition), nil}
      )

    assert new_file.path != @img
    # original file untouched
    assert "128x128" == geometry(@img)
    assert "10x10" == geometry(new_file.path)
    # new tmp file has correct extension
    assert Path.extname(new_file.path) == ".jpg"
    cleanup(new_file.path)
  end

  test "transforms a copied version of file according to a function transformation that returns a list" do
    {:ok, new_file} =
      Waffle.Processor.process(
        DummyDefinition,
        :small,
        {Waffle.File.new(@img, DummyDefinition), nil}
      )

    assert new_file.path != @img
    # original file untouched
    assert "128x128" == geometry(@img)
    assert "10x10" == geometry(new_file.path)
    cleanup(new_file.path)
  end

  test "transforms with a custom function" do
    {:ok, new_file} =
      Waffle.Processor.process(
        DummyDefinition,
        :custom,
        {Waffle.File.new(@img, DummyDefinition), nil}
      )

    assert new_file.path != @img
    # original file untouched
    assert "128x128" == geometry(@img)
    assert "1x1" == geometry(new_file.path)
    cleanup(new_file.path)
  end

  test "transforms with custom functions" do
    {:ok, new_file} =
      Waffle.Processor.process(
        DummyDefinition,
        :custom_with_ext,
        {Waffle.File.new(@img, DummyDefinition), nil}
      )

    assert new_file.path != @img
    # original file untouched
    assert "128x128" == geometry(@img)
    assert "1x1" == geometry(new_file.path)
    assert Path.extname(new_file.path) == ".jpg"
    cleanup(new_file.path)
  end

  test "transforms a file given as a binary" do
    img_binary = File.read!(@img)

    {:ok, new_file} =
      Waffle.Processor.process(
        DummyDefinition,
        :small,
        {Waffle.File.new(%{binary: img_binary, filename: "image.png"}, DummyDefinition), nil}
      )

    assert new_file.path != @img
    # original file untouched
    assert "128x128" == geometry(@img)
    assert "10x10" == geometry(new_file.path)
    # new tmp file has correct extension
    assert Path.extname(new_file.path) == ".jpg"
    cleanup(new_file.path)
  end

  test "file names with spaces" do
    {:ok, new_file} =
      Waffle.Processor.process(
        DummyDefinition,
        :thumb,
        {Waffle.File.new(@img2, DummyDefinition), nil}
      )

    assert new_file.path != @img2
    # original file untouched
    assert "128x128" == geometry(@img2)
    assert "10x10" == geometry(new_file.path)
    cleanup(new_file.path)
  end

  test "returns tuple in an invalid transformation" do
    assert {:error, _} =
             Waffle.Processor.process(
               BrokenDefinition,
               :thumb,
               {Waffle.File.new(@img, BrokenDefinition), nil}
             )
  end

  test "raises an error if the given transformation executable cannot be found" do
    assert_raise Waffle.MissingExecutableError, ~r"blah", fn ->
      Waffle.Processor.process(
        MissingExecutableDefinition,
        :original,
        {Waffle.File.new(@img, MissingExecutableDefinition), nil}
      )
    end
  end

  defp geometry(path) do
    {identify, 0} = System.cmd("identify", ["-verbose", path], stderr_to_stdout: true)
    Enum.at(Regex.run(~r/Geometry: ([^+]*)/, identify), 1)
  end

  defp cleanup(path) do
    File.rm(path)
  end
end
