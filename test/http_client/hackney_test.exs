defmodule WaffleTest.HTTPClient.Hackney do
  use ExUnit.Case, async: false
  import Mock

  alias Waffle.HTTPClient.Hackney

  describe "get/3" do
    test "returns {:ok, body} on 200 with no content-disposition header" do
      with_mock :hackney,
        get: fn _url, _headers, "", _opts -> {:ok, 200, [], :client_ref} end,
        body: fn :client_ref, :infinity -> {:ok, "file content"} end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:ok, "file content"}
      end
    end

    test "returns {:ok, body, filename} when content-disposition header is present" do
      response_headers = [{"content-disposition", ~s(attachment; filename="photo.jpg")}]

      with_mock :hackney,
        get: fn _url, _headers, "", _opts -> {:ok, 200, response_headers, :client_ref} end,
        body: fn :client_ref, :infinity -> {:ok, "file content"} end do
        result = Hackney.get("http://example.com/file", [], [])
        assert result == {:ok, "file content", "photo.jpg"}
      end
    end

    test "returns {:error, :service_unavailable} on 503" do
      with_mock :hackney,
        get: fn _url, _headers, "", _opts -> {:ok, 503, [], :client_ref} end,
        close: fn :client_ref -> :ok end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, :service_unavailable}
      end
    end

    test "returns {:error, {:http_error, :unexpected_status}} on non-200/503 status" do
      with_mock :hackney,
        get: fn _url, _headers, "", _opts -> {:ok, 404, [], :client_ref} end,
        close: fn :client_ref -> :ok end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, {:http_error, :unexpected_status}}
      end
    end

    test "returns {:error, :timeout} on hackney timeout map" do
      with_mock :hackney,
        get: fn _url, _headers, "", _opts -> {:error, %{reason: :timeout}} end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, :timeout}
      end
    end

    test "returns {:error, :timeout} on :timeout atom" do
      with_mock :hackney,
        get: fn _url, _headers, "", _opts -> {:error, :timeout} end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, :timeout}
      end
    end

    test "returns {:error, {:http_error, reason}} on other errors" do
      with_mock :hackney,
        get: fn _url, _headers, "", _opts -> {:error, :econnrefused} end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, {:http_error, :econnrefused}}
      end
    end

    test "passes recv_timeout and connect_timeout to hackney" do
      with_mock :hackney,
        get: fn _url, _headers, "", opts ->
          assert Keyword.get(opts, :recv_timeout) == 3_000
          assert Keyword.get(opts, :connect_timeout) == 8_000
          {:ok, 200, [], :client_ref}
        end,
        body: fn :client_ref, :infinity -> {:ok, "body"} end do
        Hackney.get("http://example.com/file.jpg", [],
          recv_timeout: 3_000,
          connect_timeout: 8_000
        )
      end
    end

    test "passes max_body_length to hackney body read" do
      with_mock :hackney,
        get: fn _url, _headers, "", _opts -> {:ok, 200, [], :client_ref} end,
        body: fn :client_ref, max ->
          assert max == 1024
          {:ok, "body"}
        end do
        Hackney.get("http://example.com/file.jpg", [], max_body_length: 1024)
      end
    end
  end
end
