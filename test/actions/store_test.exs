defmodule WaffleTest.Actions.Store do
  use ExUnit.Case, async: false

  @img "test/support/image.png"
  @remote_img_with_space_image_two "https://github.com/elixir-waffle/waffle/blob/master/test/support/image%20two.png"

  import Mock

  setup {Req.Test, :verify_on_exit!}

  setup do
    request_options = Application.get_env(:waffle, :request, [])

    Application.put_env(
      :waffle,
      :request,
      Keyword.put(request_options, :max_retries, 0)
    )

    on_exit(fn -> Application.put_env(:waffle, :request, request_options) end)
  end

  defmodule DummyDefinition do
    use Waffle.Actions.Store
    use Waffle.Definition.Storage

    def validate({file, _}),
      do: String.ends_with?(file.file_name, ".png") || String.ends_with?(file.file_name, ".ico")

    def transform(:skipped, _), do: :skip
    def transform(_, _), do: :noaction
    def __versions, do: [:original, :thumb, :skipped]
  end

  defmodule DummyDefinitionWithExtension do
    use Waffle.Actions.Store
    use Waffle.Definition.Storage

    def validate({file, _}), do: String.ends_with?(file.file_name, ".png")

    def transform(:convert_to_jpg, _),
      do: {:convert, "-format jpg", :jpg}

    def transform(:custom_to_jpg, {file, _}) do
      {
        fn _, _ -> {:ok, file} end,
        fn _, _ -> :jpg end
      }
    end

    def __versions, do: [:convert_to_jpg, :custom_to_jpg]
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

  test_with_mock "custom transformations change a file extension", Waffle.Storage.S3,
    put: fn DummyDefinitionWithExtension, _, {%{file_name: "image.jpg", path: _}, nil} ->
      {:ok, "resp"}
    end do
    assert DummyDefinitionWithExtension.store(@img) == {:ok, "image.png"}
  end

  test "checks file existence" do
    assert DummyDefinition.store("non-existent-file.png") == {:error, :invalid_file_path}
  end

  test "delegates to definition validation" do
    assert DummyDefinition.store(__ENV__.file) == {:error, :invalid_file}
  end

  test "supports custom validation error message" do
    assert DummyDefinitionWithValidationError.store(__ENV__.file) == {:error, "invalid file type"}
  end

  test_with_mock "single binary argument is interpreted as file path", Waffle.Storage.S3,
    put: fn DummyDefinition, _, {%{file_name: "image.png", path: @img}, nil} ->
      {:ok, "resp"}
    end do
    assert DummyDefinition.store(@img) == {:ok, "image.png"}
  end

  test_with_mock "two-tuple argument interpreted as path and scope", Waffle.Storage.S3,
    put: fn DummyDefinition, _, {%{file_name: "image.png", path: @img}, :scope} ->
      {:ok, "resp"}
    end do
    assert DummyDefinition.store({@img, :scope}) == {:ok, "image.png"}
  end

  test_with_mock "map with a filename and path", Waffle.Storage.S3,
    put: fn DummyDefinition, _, {%{file_name: "image.png", path: @img}, nil} ->
      {:ok, "resp"}
    end do
    assert DummyDefinition.store(%{filename: "image.png", path: @img}) == {:ok, "image.png"}
  end

  test_with_mock "two-tuple with Plug.Upload and a scope", Waffle.Storage.S3,
    put: fn DummyDefinition, _, {%{file_name: "image.png", path: @img}, :scope} ->
      {:ok, "resp"}
    end do
    assert DummyDefinition.store({%{filename: "image.png", path: @img}, :scope}) ==
             {:ok, "image.png"}
  end

  test_with_mock "error from ExAws on upload to S3", Waffle.Storage.S3,
    put: fn DummyDefinition, _, {%{file_name: "image.png", path: @img}, :scope} ->
      {:error, {:http_error, 404, "XML"}}
    end do
    assert DummyDefinition.store({%{filename: "image.png", path: @img}, :scope}) ==
             {:error, [{:http_error, 404, "XML"}, {:http_error, 404, "XML"}]}
  end

  test_with_mock "timeout", Waffle.Storage.S3,
    put: fn DummyDefinition, _, {%{file_name: "image.png", path: @img}, :scope} ->
      :timer.sleep(100) && {:ok, "favicon.ico"}
    end do
    Application.put_env(:waffle, :version_timeout, 1)

    catch_exit(
      assert DummyDefinition.store({%{filename: "image.png", path: @img}, :scope}) ==
               {:ok, "image.png"}
    )

    Application.put_env(:waffle, :version_timeout, 15_000)
  end

  test_with_mock "receive timeout", Waffle.Storage.S3,
    put: fn DummyDefinition, _, {%{file_name: "favicon.ico", path: _}, nil} ->
      {:ok, "favicon.ico"}
    end do
    Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Waffle.HTTPClient.Error{error: :timeout}} =
             DummyDefinition.store("https://www.google.com/favicon.ico")
  end

  test_with_mock "receive timeout with a filename", Waffle.Storage.S3,
    put: fn DummyDefinition, _, {%{file_name: "newfavicon.ico", path: _}, nil} ->
      {:ok, "newfavicon.ico"}
    end do
    Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Waffle.HTTPClient.Error{error: :timeout}} =
             DummyDefinition.store(%{
               remote_path: "https://www.google.com/favicon.ico",
               filename: "newfavicon.ico"
             })
  end

  test_with_mock "accepts remote files", Waffle.Storage.S3,
    put: fn DummyDefinition, _, {%{file_name: "favicon.ico", path: _}, nil} ->
      {:ok, "favicon.ico"}
    end do
    Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
      Plug.Conn.send_resp(conn, 200, "file content")
    end)

    assert DummyDefinition.store("https://www.google.com/favicon.ico") == {:ok, "favicon.ico"}
  end

  test_with_mock "sets remote filename from content-disposition header when available",
                 Waffle.Storage.S3,
                 put: fn DummyDefinition, _, {%{file_name: "image three.png", path: _}, nil} ->
                   {:ok, "image three.png"}
                 end do
    Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
      conn
      |> Plug.Conn.put_resp_header(
        "content-disposition",
        ~s(attachment; filename="image three.png")
      )
      |> Plug.Conn.send_resp(200, "file content")
    end)

    assert DummyDefinition.store(@remote_img_with_space_image_two) ==
             {:ok, "image three.png"}
  end

  test_with_mock "sets HTTP headers for request to remote file", Waffle.Storage.S3,
    put: fn DummyDefinitionWithHeaders, _, {%{file_name: "favicon.ico", path: _}, nil} ->
      {:ok, "favicon.ico"}
    end do
    Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
      assert Plug.Conn.get_req_header(conn, "user-agent") == ["MyApp"]
      Plug.Conn.send_resp(conn, 200, "file content")
    end)

    assert DummyDefinitionWithHeaders.store("https://www.google.com/favicon.ico") ==
             {:ok, "favicon.ico"}
  end

  test_with_mock "accepts remote files with spaces", Waffle.Storage.S3,
    put: fn DummyDefinition, _, {%{file_name: "image two.png", path: _}, nil} ->
      {:ok, "image two.png"}
    end do
    Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
      Plug.Conn.send_resp(conn, 200, "file content")
    end)

    assert DummyDefinition.store(@remote_img_with_space_image_two) == {:ok, "image two.png"}
  end

  test_with_mock "accepts remote files with filenames", Waffle.Storage.S3,
    put: fn DummyDefinition, _, {%{file_name: "newfavicon.ico", path: _}, nil} ->
      {:ok, "newfavicon.ico"}
    end do
    Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
      Plug.Conn.send_resp(conn, 200, "file content")
    end)

    assert DummyDefinition.store(%{
             remote_path: "https://www.google.com/favicon.ico",
             filename: "newfavicon.ico"
           }) == {:ok, "newfavicon.ico"}
  end

  test_with_mock "rejects remote files with filenames and invalid remote path",
                 Waffle.Storage.S3,
                 put: fn DummyDefinition, _, {%{file_name: "newfavicon.ico", path: _}, nil} ->
                   {:ok, "newfavicon.ico"}
                 end do
    assert DummyDefinition.store(%{remote_path: "path/favicon.ico", filename: "newfavicon.ico"}) ==
             {:error, :invalid_file_path}
  end
end
