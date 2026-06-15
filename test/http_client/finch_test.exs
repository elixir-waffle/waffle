defmodule WaffleTest.HTTPClient.Finch do
  use ExUnit.Case, async: false
  import Mock

  defp response(status, headers \\ [], body \\ "") do
    %Finch.Response{status: status, headers: headers, body: body}
  end

  describe "get/3" do
    test "returns {:ok, body} on 200 with no content-disposition header" do
      with_mock Finch, [:passthrough],
        request: fn _req, _pool, _opts -> {:ok, response(200, [], "file content")} end do
        result = Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], [])
        assert result == {:ok, "file content"}
      end
    end

    test "returns {:ok, body, filename} when content-disposition header is present" do
      headers = [{"content-disposition", ~s(attachment; filename="photo.jpg")}]

      with_mock Finch, [:passthrough],
        request: fn _req, _pool, _opts -> {:ok, response(200, headers, "file content")} end do
        result = Waffle.HTTPClient.Finch.get("http://example.com/file", [], [])
        assert result == {:ok, "file content", "photo.jpg"}
      end
    end

    test "returns {:error, {:http_error, :body_too_large}} when body exceeds max_body_length" do
      with_mock Finch, [:passthrough],
        request: fn _req, _pool, _opts -> {:ok, response(200, [], "long body")} end do
        result =
          Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], max_body_length: 4)

        assert result == {:error, {:http_error, :body_too_large}}
      end
    end

    test "returns {:error, :service_unavailable} on 503" do
      with_mock Finch, [:passthrough],
        request: fn _req, _pool, _opts -> {:ok, response(503)} end do
        result = Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], [])
        assert result == {:error, :service_unavailable}
      end
    end

    test "returns {:error, {:http_error, :unexpected_status}} on non-200/503 status" do
      with_mock Finch, [:passthrough],
        request: fn _req, _pool, _opts -> {:ok, response(404)} end do
        result = Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], [])
        assert result == {:error, {:http_error, :unexpected_status}}
      end
    end

    test "returns {:error, :timeout} on timeout exception" do
      with_mock Finch, [:passthrough],
        request: fn _req, _pool, _opts ->
          {:error, %Mint.TransportError{reason: :timeout}}
        end do
        result = Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], [])
        assert result == {:error, :timeout}
      end
    end

    test "returns {:error, {:http_error, reason}} on other transport errors" do
      with_mock Finch, [:passthrough],
        request: fn _req, _pool, _opts ->
          {:error, %Mint.TransportError{reason: :econnrefused}}
        end do
        result = Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], [])
        assert result == {:error, {:http_error, %Mint.TransportError{reason: :econnrefused}}}
      end
    end

    test "passes recv_timeout as receive_timeout to Finch" do
      with_mock Finch, [:passthrough],
        request: fn _req, _pool, opts ->
          assert Keyword.get(opts, :receive_timeout) == 3_000
          {:ok, response(200, [], "body")}
        end do
        Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], recv_timeout: 3_000)
      end
    end

    test "uses configured pool_name" do
      Application.put_env(:waffle, Waffle.HTTPClient.Finch, pool_name: MyApp.Finch)

      on_exit(fn -> Application.delete_env(:waffle, Waffle.HTTPClient.Finch) end)

      with_mock Finch, [:passthrough],
        request: fn _req, pool, _opts ->
          assert pool == MyApp.Finch
          {:ok, response(200, [], "body")}
        end do
        Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], [])
      end
    end
  end
end
