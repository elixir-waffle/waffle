defmodule WaffleTest.HTTPClient.Req do
  use ExUnit.Case, async: false
  import Plug.Conn

  alias Waffle.HTTPClient.Req, as: Client

  @stub __MODULE__.Stub

  setup do
    Application.put_env(:waffle, Client, req_options: [plug: {Req.Test, @stub}])
    on_exit(fn -> Application.delete_env(:waffle, Client) end)
    :ok
  end

  defp stub(fun), do: Req.Test.stub(@stub, fun)

  describe "get/3" do
    test "returns {:ok, body} on 200 with no content-disposition" do
      stub(fn conn -> send_resp(conn, 200, "file content") end)
      assert Client.get("http://example.com/file.jpg", [], []) == {:ok, "file content"}
    end

    test "returns {:ok, body, filename} when content-disposition has a quoted filename" do
      stub(fn conn ->
        conn
        |> put_resp_header("content-disposition", ~s(attachment; filename="photo.jpg"))
        |> send_resp(200, "file content")
      end)

      assert Client.get("http://example.com/file", [], []) ==
               {:ok, "file content", "photo.jpg"}
    end

    test "decodes an RFC 5987 content-disposition filename" do
      stub(fn conn ->
        conn
        |> put_resp_header("content-disposition", "attachment; filename*=UTF-8''na%C3%AFve.txt")
        |> send_resp(200, "x")
      end)

      assert Client.get("http://example.com/file", [], []) == {:ok, "x", "naïve.txt"}
    end

    test "follows redirects" do
      stub(fn conn ->
        case conn.request_path do
          "/start" ->
            conn |> put_resp_header("location", "/final") |> send_resp(302, "")

          "/final" ->
            send_resp(conn, 200, "redirected body")
        end
      end)

      assert Client.get("http://example.com/start", [], []) == {:ok, "redirected body"}
    end

    test "returns {:error, {:http_error, :too_many_redirects}} when the redirect limit is hit" do
      Application.put_env(:waffle, Client,
        req_options: [plug: {Req.Test, @stub}, max_redirects: 1]
      )

      stub(fn conn ->
        conn |> put_resp_header("location", "/next") |> send_resp(302, "")
      end)

      assert Client.get("http://example.com/loop", [], []) ==
               {:error, {:http_error, :too_many_redirects}}
    end

    test "returns {:error, :service_unavailable} on 503" do
      stub(fn conn -> send_resp(conn, 503, "") end)
      assert Client.get("http://example.com/file.jpg", [], []) == {:error, :service_unavailable}
    end

    test "returns {:error, {:http_error, status}} on other non-200 statuses" do
      stub(fn conn -> send_resp(conn, 404, "") end)
      assert Client.get("http://example.com/file.jpg", [], []) == {:error, {:http_error, 404}}
    end

    test "returns {:error, :timeout} on a transport timeout" do
      stub(fn conn -> Req.Test.transport_error(conn, :timeout) end)
      assert Client.get("http://example.com/file.jpg", [], []) == {:error, :timeout}
    end

    test "returns {:error, {:http_error, reason}} on other transport errors" do
      stub(fn conn -> Req.Test.transport_error(conn, :econnrefused) end)

      assert Client.get("http://example.com/file.jpg", [], []) ==
               {:error, {:http_error, :econnrefused}}
    end

    test "returns an error when body > max_body_length" do
      stub(fn conn -> send_resp(conn, 200, String.duplicate("a", 100)) end)

      assert Client.get("http://example.com/file.jpg", [], max_body_length: 10) ==
               {:error, {:http_error, :max_body_length_exceeded}}
    end

    test "returns the full body when <= max_body_length" do
      stub(fn conn -> send_resp(conn, 200, "small") end)

      assert Client.get("http://example.com/file.jpg", [], max_body_length: 1_000) ==
               {:ok, "small"}
    end

    test "does not decompress the response body (raw bytes)" do
      gzipped = :zlib.gzip("hello")

      stub(fn conn ->
        conn
        |> put_resp_header("content-encoding", "gzip")
        |> send_resp(200, gzipped)
      end)

      assert Client.get("http://example.com/file.gz", [], []) == {:ok, gzipped}
    end

    test "does not decode the body based on content-type (raw bytes)" do
      stub(fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, ~s({"a":1}))
      end)

      assert Client.get("http://example.com/data.json", [], []) == {:ok, ~s({"a":1})}
    end
  end
end
