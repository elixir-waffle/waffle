defmodule WaffleTest.Storage.Local do
  use ExUnit.Case
  @img "test/support/image.png"
  @badimg "test/support/invalid_image.png"
  @custom_asset_host "http://static.example.com"

  setup do
    File.mkdir_p("waffletest/uploads")
    File.mkdir_p("waffletest/tmp")
    System.put_env("TMPDIR", "waffletest/tmp")

    on_exit fn ->
      File.rm_rf("waffletest/uploads")
      File.rm_rf("waffletest/tmp")
    end
  end

  def with_env(app, key, value, fun) do
    previous = Application.get_env(app, key, :nothing)

    Application.put_env(app, key, value)
    fun.()

    case previous do
      :nothing -> Application.delete_env(app, key)
      _ -> Application.put_env(app, key, previous)
    end
  end


  defmodule DummyDefinition do
    use Waffle.Definition

    @versions [:original, :thumb, :skipped]

    def transform(:thumb, _), do: {:convert, "-strip -thumbnail 10x10"}
    def transform(:original, _), do: :noaction
    def transform(:skipped, _), do: :skip

    def storage_dir(_, _), do: "waffletest/uploads"
    def __storage, do: Waffle.Storage.Local

    def filename(:original, {file, _}), do: "original-#{Path.basename(file.file_name, Path.extname(file.file_name))}"
    def filename(:thumb, {file, _}), do: "1/thumb-#{Path.basename(file.file_name, Path.extname(file.file_name))}"
    def filename(:skipped, {file, _}), do: "1/skipped-#{Path.basename(file.file_name, Path.extname(file.file_name))}"
  end

  defmodule DummyDefinitionWithPrefix do
    use Waffle.Definition

    @versions [:original, :thumb]

    def transform(:thumb, _), do: {:convert, "-strip -thumbnail 10x10"}

    def storage_dir_prefix(), do: "priv/waffle/private"
    def storage_dir(_, _), do: "waffletest/uploads"
    def __storage, do: Waffle.Storage.Local

    def filename(:original, {file, _}), do: "original-#{Path.basename(file.file_name, Path.extname(file.file_name))}"
    def filename(:thumb, {file, _}), do: "1/thumb-#{Path.basename(file.file_name, Path.extname(file.file_name))}"
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

  test "put, delete, get with storage prefix" do
    assert {:ok, "original-image.png"} == Waffle.Storage.Local.put(DummyDefinitionWithPrefix, :original, {Waffle.File.new(%{filename: "original-image.png", path: @img}), nil})
    assert {:ok, "1/thumb-image.png"} == Waffle.Storage.Local.put(DummyDefinitionWithPrefix, :thumb, {Waffle.File.new(%{filename: "1/thumb-image.png", path: @img}), nil})

    assert File.exists?("priv/waffle/private/waffletest/uploads/original-image.png")
    assert File.exists?("priv/waffle/private/waffletest/uploads/1/thumb-image.png")
    assert "/waffletest/uploads/original-image.png" == DummyDefinitionWithPrefix.url("image.png", :original)
    assert "/waffletest/uploads/1/thumb-image.png" == DummyDefinitionWithPrefix.url("1/image.png", :thumb)

    :ok = Waffle.Storage.Local.delete(DummyDefinitionWithPrefix, :original, {%{file_name: "image.png"}, nil})
    :ok = Waffle.Storage.Local.delete(DummyDefinitionWithPrefix, :thumb, {%{file_name: "image.png"}, nil})
    refute File.exists?("priv/waffle/private/waffletest/uploads/original-image.png")
    refute File.exists?("priv/waffle/private/waffletest/uploads/1/thumb-image.png")
  end


  test "deleting when there's a skipped version" do
    DummyDefinition.store(@img)
    assert :ok = DummyDefinition.delete(@img)
  end

  test "get, delete with :asset_host set" do
    with_env :waffle, :asset_host, @custom_asset_host, fn ->

      assert {:ok, "original-image.png"} == Waffle.Storage.Local.put(DummyDefinition, :original, {Waffle.File.new(%{filename: "original-image.png", path: @img}), nil})
      assert {:ok, "1/thumb-image.png"} == Waffle.Storage.Local.put(DummyDefinition, :thumb, {Waffle.File.new(%{filename: "1/thumb-image.png", path: @img}), nil})

      assert File.exists?("waffletest/uploads/original-image.png")
      assert File.exists?("waffletest/uploads/1/thumb-image.png")
      assert @custom_asset_host <> "/waffletest/uploads/original-image.png" == DummyDefinition.url("image.png", :original)
      assert @custom_asset_host <> "/waffletest/uploads/1/thumb-image.png" == DummyDefinition.url("1/image.png", :thumb)

      :ok = Waffle.Storage.Local.delete(DummyDefinition, :original, {%{file_name: "image.png"}, nil})
      :ok = Waffle.Storage.Local.delete(DummyDefinition, :thumb, {%{file_name: "image.png"}, nil})
      refute File.exists?("waffletest/uploads/original-image.png")
      refute File.exists?("waffletest/uploads/1/thumb-image.png")
    end
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

  test "temp files from processing are cleaned up" do
    filepath = @img
    DummyDefinition.store(filepath)
    assert Enum.empty?(File.ls!("waffletest/tmp"))
  end

  test "temp files from handling binary data are cleaned up" do
    filepath = @img
    filename = "image.png"
    DummyDefinition.store(%{binary: File.read!(filepath), filename: filename})
    assert File.exists?("waffletest/uploads/original-#{filename}")
    assert Enum.empty?(File.ls!("waffletest/tmp"))
  end

  test "temp files from handling remote URLs are cleaned up" do
    DummyDefinition.store("https://www.google.com/favicon.ico")
    assert Enum.empty?(File.ls!("waffletest/tmp"))
  end
end
