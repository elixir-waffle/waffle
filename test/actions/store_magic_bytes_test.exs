defmodule WaffleTest.Actions.StoreMagicBytes do
  use ExUnit.Case, async: false

  import Mock

  @png "test/support/image.png"
  @invalid_png "test/support/invalid_image.png"

  @jpeg_magic <<0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
  @garbage <<0x00, 0x01, 0x02, 0x03>>

  defmodule DummyDefinitionWithMagicBytesValidation do
    use Waffle.Actions.Store
    use Waffle.Definition.Storage

    @allowed_types ~w(image/jpeg image/png image/gif image/webp)

    def validate({%{path: path}, _}) when not is_nil(path) do
      case MagicBytes.from_path(path) do
        {:ok, mime} when mime in @allowed_types -> :ok
        {:ok, _mime} -> {:error, "invalid file type"}
        {:error, :unknown} -> {:error, "invalid file type"}
        {:error, _} -> {:error, "could not read file"}
      end
    end

    def validate({%{stream: stream}, _}) when not is_nil(stream) do
      case MagicBytes.from_stream(stream) do
        {:ok, mime} when mime in @allowed_types -> :ok
        {:ok, _mime} -> {:error, "invalid file type"}
        {:error, :unknown} -> {:error, "invalid file type"}
        {:error, _} -> {:error, "could not read file"}
      end
    end

    def transform(_, _), do: :noaction
    def __versions, do: [:original]
  end

  test "accepts a file with valid PNG magic bytes" do
    with_mock Waffle.Storage.S3,
      put: fn DummyDefinitionWithMagicBytesValidation, _, _ -> {:ok, "resp"} end do
      assert DummyDefinitionWithMagicBytesValidation.store(@png) == {:ok, "image.png"}
      assert_called(Waffle.Storage.S3.put(DummyDefinitionWithMagicBytesValidation, :_, :_))
    end
  end

  test "rejects a file with .png extension but invalid magic bytes" do
    assert DummyDefinitionWithMagicBytesValidation.store(@invalid_png) ==
             {:error, "invalid file type"}
  end

  test "accepts a binary upload with valid JPEG magic bytes" do
    with_mock Waffle.Storage.S3,
      put: fn DummyDefinitionWithMagicBytesValidation, _, _ -> {:ok, "resp"} end do
      assert DummyDefinitionWithMagicBytesValidation.store(%{
               filename: "photo.jpg",
               binary: @jpeg_magic
             }) ==
               {:ok, "photo.jpg"}

      assert_called(Waffle.Storage.S3.put(DummyDefinitionWithMagicBytesValidation, :_, :_))
    end
  end

  test "rejects a binary upload with unrecognised magic bytes" do
    assert DummyDefinitionWithMagicBytesValidation.store(%{
             filename: "photo.jpg",
             binary: @garbage
           }) ==
             {:error, "invalid file type"}
  end
end
