defmodule WaffleTest.File do
  use ExUnit.Case, async: false

  setup {Req.Test, :verify_on_exit!}

  @custom_tmp_dir System.tmp_dir() <> "/waffle_test_custom"

  defmodule DummyDefinition do
    use Waffle.Definition.Storage
    def transform(_, _), do: :noaction
    def __versions, do: [:original]
  end

  describe "generate_temporary_path/1" do
    test "uses configured tmp_dir" do
      File.mkdir_p!(@custom_tmp_dir)
      Application.put_env(:waffle, :tmp_dir, @custom_tmp_dir)

      assert Waffle.File.generate_temporary_path() |> String.starts_with?(@custom_tmp_dir)

      on_exit(fn ->
        Application.delete_env(:waffle, :tmp_dir)
        File.rm_rf!(@custom_tmp_dir)
      end)
    end

    test "uses system tmp_dir" do
      assert Waffle.File.generate_temporary_path() |> String.starts_with?(System.tmp_dir())
    end
  end

  describe "new/2" do
    setup do
      request_options = Application.get_env(:waffle, :request, [])

      Application.put_env(
        :waffle,
        :request,
        Keyword.merge(request_options, max_retries: 1, backoff_factor_ms: 0)
      )

      on_exit(fn -> Application.put_env(:waffle, :request, request_options) end)
    end

    test "retries on 503" do
      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        Plug.Conn.send_resp(conn, 503, "service unavailable")
      end)

      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        Plug.Conn.send_resp(conn, 200, "file content")
      end)

      assert %Waffle.File{file_name: "image.jpg", path: path, is_tempfile?: true} =
               Waffle.File.new("http://example.com/image.jpg", DummyDefinition)

      on_exit(fn -> File.rm(path) end)
    end

    test "retries on timeout" do
      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        Plug.Conn.send_resp(conn, 200, "file content")
      end)

      assert %Waffle.File{file_name: "image.jpg", path: path, is_tempfile?: true} =
               Waffle.File.new("http://example.com/image.jpg", DummyDefinition)

      on_exit(fn -> File.rm(path) end)
    end

    test "returns error when retry doesn't recover" do
      Req.Test.expect(Waffle.HTTPClient.Req, 2, fn conn ->
        Plug.Conn.send_resp(conn, 503, "service unavailable")
      end)

      assert {:error,
              %Waffle.HTTPClient.Error{
                error: {:unexpected_status, 503},
                error_context: %Req.Response{status: 503, body: "service unavailable"}
              }} = Waffle.File.new("http://example.com/image.jpg", DummyDefinition)
    end

    test "doesn't retry on other http codes" do
      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        Plug.Conn.send_resp(conn, 404, "not found")
      end)

      assert {:error,
              %Waffle.HTTPClient.Error{
                error: {:unexpected_status, 404}
              }} = Waffle.File.new("http://example.com/image.jpg", DummyDefinition)
    end

    test "doesn't retry on other errors" do
      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error,
              %Waffle.HTTPClient.Error{
                error: :http_client,
                error_context: %Req.TransportError{reason: :econnrefused}
              }} = Waffle.File.new("http://example.com/image.jpg", DummyDefinition)
    end
  end
end
