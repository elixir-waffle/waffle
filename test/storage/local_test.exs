defmodule WaffleTest.Storage.Local do
  use ExUnit.Case
  @img "test/support/image.png"
  @badimg "test/support/invalid_image.png"

  setup_all do
    File.mkdir_p("waffletest/uploads")

    on_exit fn ->
      File.rm_rf("waffletest/uploads")
    end
  end


  defmodule DummyDefinition do
    use Waffle.Actions.Store
    use Waffle.Definition.Storage
    use Waffle.Actions.Url

    @acl :public_read
    def transform(:thumb, _), do: {:convert, "-strip -thumbnail 10x10"}
    def transform(:original, _), do: :noaction
    def transform(:skipped, _), do: :skip
    def __versions, do: [:original, :thumb, :skipped]
    def storage_dir(_, _), do: "waffletest/uploads"
    def __storage, do: Waffle.Storage.Local
    def filename(:original, {file, _}), do: "original-#{Path.basename(file.file_name, Path.extname(file.file_name))}"
    def filename(:thumb, {file, _}), do: "1/thumb-#{Path.basename(file.file_name, Path.extname(file.file_name))}"
    def filename(:skipped, {file, _}), do: "1/skipped-#{Path.basename(file.file_name, Path.extname(file.file_name))}"
  end

  test "put, delete, get" do
    assert {:ok, "original-image.png"} == Waffle.Storage.Local.put(DummyDefinition, :original, {Waffle.File.new(%{filename: "original-image.png", path: @img}), nil})
    assert {:ok, "1/thumb-image.png"} == Waffle.Storage.Local.put(DummyDefinition, :thumb, {Waffle.File.new(%{filename: "1/thumb-image.png", path: @img}), nil})

    assert File.exists?("waffletest/uploads/original-image.png")
    assert File.exists?("waffletest/uploads/1/thumb-image.png")
    assert "/waffletest/uploads/original-image.png" == DummyDefinition.url("image.png", :original)
    assert "/waffletest/uploads/1/thumb-image.png" == DummyDefinition.url("1/image.png", :thumb)

    :ok = Waffle.Storage.Local.delete(DummyDefinition, :original, {%{file_name: "image.png"}, nil})
    :ok = Waffle.Storage.Local.delete(DummyDefinition, :thumb, {%{file_name: "image.png"}, nil})
    refute File.exists?("waffletest/uploads/original-image.png")
    refute File.exists?("waffletest/uploads/1/thumb-image.png")
  end

  test "save binary" do
    Waffle.Storage.Local.put(DummyDefinition, :original, {Waffle.File.new(%{binary: "binary", filename: "binary.png"}), nil})
    assert true == File.exists?("waffletest/uploads/binary.png")
  end

  test "encoded url" do
    url = DummyDefinition.url(Waffle.File.new(%{binary: "binary", filename: "binary file.png"}), :original)
    assert "/waffletest/uploads/original-binary%20file.png" == url
  end

  test "url for skipped version" do
    url = DummyDefinition.url(Waffle.File.new(%{binary: "binary", filename: "binary file.png"}), :skipped)
    assert url == nil
  end

  test "if one transform fails, they all fail" do
    filepath = @badimg
    [filename] = String.split(@img, "/") |> Enum.reverse |> Enum.take(1)
    assert File.exists?(filepath)
    DummyDefinition.store(filepath)

    assert !File.exists?("waffletest/uploads/original-#{filename}")
    assert !File.exists?("waffletest/uploads/1/thumb-#{filename}")
  end
end
