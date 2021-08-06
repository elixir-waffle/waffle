defmodule WaffleTest.Actions.Store do
  use ExUnit.Case, async: false

  @img "test/support/image.png"
  @remote_img_with_space_image_two "https://github.com/elixir-waffle/waffle/blob/master/test/support/image%20two.png"

  import Mock

  defmodule DummyDefinition do
    use Waffle.Actions.Store
    use Waffle.Definition.Storage

    def validate({file, _}),
      do: String.ends_with?(file.file_name, ".png") || String.ends_with?(file.file_name, ".ico")

    def transform(:skipped, _), do: :skip
    def transform(_, _), do: :noaction
    def __versions, do: [:original, :thumb, :skipped]
  end

  defmodule DummyDefinitionWithHeaders do
    use Waffle.Actions.Store
    use Waffle.Definition.Storage

    def transform(_, _), do: :noaction
    def __versions, do: [:original, :thumb, :skipped]
    def remote_file_headers(%URI{host: "www.google.com"}), do: [{"User-Agent", "MyApp"}]
  end

  defmodule DummyDefinitionWithValidationError do
    use Waffle.Actions.Store
    use Waffle.Definition.Storage

    def validate(_), do: {:error, "invalid file type"}
    def transform(_, _), do: :noaction
    def __versions, do: [:original, :thumb, :skipped]
  end

  test "checks file existance" do
    assert DummyDefinition.store("non-existant-file.png") == {:error, :invalid_file_path}
  end

  test "delegates to definition validation" do
    assert DummyDefinition.store(__ENV__.file) == {:error, :invalid_file}
  end

  test "supports custom validation error message" do
    assert DummyDefinitionWithValidationError.store(__ENV__.file) == {:error, "invalid file type"}
  end

  test "single binary argument is interpreted as file path" do
    with_mock Waffle.Storage.S3,
      put: fn DummyDefinition, _, {%{file_name: "image.png", path: @img}, nil} ->
        {:ok, "resp"}
      end do
      assert DummyDefinition.store(@img) == {:ok, "image.png"}
    end
  end

  test "two-tuple argument interpreted as path and scope" do
    with_mock Waffle.Storage.S3,
      put: fn DummyDefinition, _, {%{file_name: "image.png", path: @img}, :scope} ->
        {:ok, "resp"}
      end do
      assert DummyDefinition.store({@img, :scope}) == {:ok, "image.png"}
    end
  end

  test "map with a filename and path" do
    with_mock Waffle.Storage.S3,
      put: fn DummyDefinition, _, {%{file_name: "image.png", path: @img}, nil} ->
        {:ok, "resp"}
      end do
      assert DummyDefinition.store(%{filename: "image.png", path: @img}) == {:ok, "image.png"}
    end
  end

  test "two-tuple with Plug.Upload and a scope" do
    with_mock Waffle.Storage.S3,
      put: fn DummyDefinition, _, {%{file_name: "image.png", path: @img}, :scope} ->
        {:ok, "resp"}
      end do
      assert DummyDefinition.store({%{filename: "image.png", path: @img}, :scope}) ==
               {:ok, "image.png"}
    end
  end

  test "error from ExAws on upload to S3" do
    with_mock Waffle.Storage.S3,
      put: fn DummyDefinition, _, {%{file_name: "image.png", path: @img}, :scope} ->
        {:error, {:http_error, 404, "XML"}}
      end do
      assert DummyDefinition.store({%{filename: "image.png", path: @img}, :scope}) ==
               {:error, [{:http_error, 404, "XML"}, {:http_error, 404, "XML"}]}
    end
  end

  test "timeout" do
    Application.put_env(:waffle, :version_timeout, 1)

    catch_exit do
      with_mock Waffle.Storage.S3,
        put: fn DummyDefinition, _, {%{file_name: "image.png", path: @img}, :scope} ->
          :timer.sleep(100) && {:ok, "favicon.ico"}
        end do
        assert DummyDefinition.store({%{filename: "image.png", path: @img}, :scope}) ==
                 {:ok, "image.png"}
      end
    end

    Application.put_env(:waffle, :version_timeout, 15_000)
  end

  test "accepts remote files" do
    with_mock Waffle.Storage.S3,
      put: fn DummyDefinition, _, {%{file_name: "favicon.ico", path: _}, nil} ->
        {:ok, "favicon.ico"}
      end do
      assert DummyDefinition.store("https://www.google.com/favicon.ico") == {:ok, "favicon.ico"}
    end
  end

  test "sets remote filename from content-disposition header when available" do
    with_mocks([
      {
        :hackney_headers,
        [:passthrough],
        get_value: fn "content-disposition", _headers ->
          "attachment; filename=\"image three.png\""
        end
      },
      {
        Waffle.Storage.S3,
        [],
        put: fn DummyDefinition, _, {%{file_name: "image three.png", path: _}, nil} ->
          {:ok, "image three.png"}
        end
      }
    ]) do
      assert DummyDefinition.store(@remote_img_with_space_image_two) ==
               {:ok, "image three.png"}
    end
  end

  test "sets HTTP headers for request to remote file" do
    with_mocks([
      {
        :hackney,
        [:passthrough],
        []
      },
      {
        Waffle.Storage.S3,
        [],
        put: fn DummyDefinitionWithHeaders, _, {%{file_name: "favicon.ico", path: _}, nil} ->
          {:ok, "favicon.ico"}
        end
      }
    ]) do
      DummyDefinitionWithHeaders.store("https://www.google.com/favicon.ico")

      assert_called(
        :hackney.get("https://www.google.com/favicon.ico", [{"User-Agent", "MyApp"}], "", :_)
      )
    end
  end

  test "accepts remote files with spaces" do
    with_mock Waffle.Storage.S3,
      put: fn DummyDefinition, _, {%{file_name: "image two.png", path: _}, nil} ->
        {:ok, "image two.png"}
      end do
      assert DummyDefinition.store(@remote_img_with_space_image_two) == {:ok, "image two.png"}
    end
  end

  test "accepts remote files with filenames" do
    with_mock Waffle.Storage.S3,
      put: fn DummyDefinition, _, {%{file_name: "newfavicon.ico", path: _}, nil} ->
        {:ok, "newfavicon.ico"}
      end do
      assert DummyDefinition.store(%{
               remote_path: "https://www.google.com/favicon.ico",
               filename: "newfavicon.ico"
             }) == {:ok, "newfavicon.ico"}
    end
  end

  test "rejects remote files with filenames and invalid remote path" do
    with_mock Waffle.Storage.S3,
      put: fn DummyDefinition, _, {%{file_name: "newfavicon.ico", path: _}, nil} ->
        {:ok, "newfavicon.ico"}
      end do
      assert DummyDefinition.store(%{remote_path: "path/favicon.ico", filename: "newfavicon.ico"}) ==
               {:error, :invalid_file_path}
    end
  end
end
