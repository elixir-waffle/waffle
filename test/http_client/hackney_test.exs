defmodule WaffleTest.HTTPClient.Hackney do
  use ExUnit.Case, async: false
  import Mock
  import WaffleTest.Support.HackneyMock, only: [mock_hackney_messages: 1]

  alias Waffle.HTTPClient.Hackney

  describe "get/3 successful responses" do
    test "returns {:ok, body} on 200 with no content-disposition header" do
      {ref, send_auto, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, "file content", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", opts ->
          assert {:async, :once} in opts
          send_auto.()
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          send_next.()
          :ok
        end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:ok, "file content"}
      end
    end

    test "returns {:ok, body, filename} when content-disposition has a quoted filename" do
      response_headers = [{"content-disposition", ~s(attachment; filename="photo.jpg")}]

      {ref, send_auto, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, response_headers}, "file content", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_auto.()
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          send_next.()
          :ok
        end do
        result = Hackney.get("http://example.com/file", [], [])
        assert result == {:ok, "file content", "photo.jpg"}
      end
    end

    test "returns {:ok, body, filename} when content-disposition has an unquoted filename" do
      response_headers = [{"content-disposition", "attachment; filename=photo.jpg"}]

      {ref, send_auto, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, response_headers}, "file content", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_auto.()
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          send_next.()
          :ok
        end do
        result = Hackney.get("http://example.com/file", [], [])
        assert result == {:ok, "file content", "photo.jpg"}
      end
    end

    test "returns {:ok, body, filename} decoded from RFC 5987 filename*=" do
      response_headers = [{"content-disposition", "attachment; filename*=UTF-8''my%20photo.jpg"}]

      {ref, send_auto, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, response_headers}, "file content", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_auto.()
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          send_next.()
          :ok
        end do
        result = Hackney.get("http://example.com/file", [], [])
        assert result == {:ok, "file content", "my photo.jpg"}
      end
    end

    test "prefers filename*= over filename= when both are present" do
      response_headers = [
        {"content-disposition",
         ~s(attachment; filename="fallback.jpg"; filename*=UTF-8''preferred.jpg)}
      ]

      {ref, send_auto, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, response_headers}, "file content", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_auto.()
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          send_next.()
          :ok
        end do
        result = Hackney.get("http://example.com/file", [], [])
        assert result == {:ok, "file content", "preferred.jpg"}
      end
    end

    test "returns {:ok, body} when content-disposition has no filename parameter" do
      response_headers = [{"content-disposition", "inline"}]

      {ref, send_auto, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, response_headers}, "file content", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_auto.()
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          send_next.()
          :ok
        end do
        result = Hackney.get("http://example.com/file", [], [])
        assert result == {:ok, "file content"}
      end
    end

    test "concatenates multiple body chunks in order" do
      {ref, send_auto, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, "ab", "cd", "ef", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_auto.()
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          send_next.()
          :ok
        end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:ok, "abcdef"}
      end
    end
  end

  describe "get/3 non-200 responses" do
    test "returns {:error, :service_unavailable} on 503 and closes the connection" do
      {ref, send_auto, _send_next} = mock_hackney_messages([{:status, 503, "Service Unavailable"}])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_auto.()
          {:ok, ref}
        end,
        close: fn ^ref -> :ok end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, :service_unavailable}
        assert_called(:hackney.close(:_))
      end
    end

    test "returns {:error, {:http_error, status}} with the actual HTTP status on non-200/503 and closes the connection" do
      {ref, send_auto, _send_next} = mock_hackney_messages([{:status, 404, "Not Found"}])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_auto.()
          {:ok, ref}
        end,
        close: fn ^ref -> :ok end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, {:http_error, 404}}
        assert_called(:hackney.close(:_))
      end
    end
  end

  describe "get/3 redirects" do
    test "follows a 301 redirect and returns the body from the final location" do
      {ref1, send_auto1, _send_next1} =
        mock_hackney_messages([{:redirect, "http://example.com/final.jpg", []}])

      {ref2, send_auto2, send_next2} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, "final content", :done])

      with_mock :hackney,
        get: fn
          "http://example.com/original.jpg", _headers, "", _opts ->
            send_auto1.()
            {:ok, ref1}

          "http://example.com/final.jpg", _headers, "", _opts ->
            send_auto2.()
            {:ok, ref2}
        end,
        stream_next: fn ^ref2 ->
          send_next2.()
          :ok
        end,
        close: fn _ref -> :ok end do
        result = Hackney.get("http://example.com/original.jpg", [], [])
        assert result == {:ok, "final content"}
      end
    end

    test "follows a 303 see_other redirect (e.g. after a POST) the same way as a redirect" do
      {ref1, send_auto1, _send_next1} =
        mock_hackney_messages([{:see_other, "http://example.com/final.jpg", []}])

      {ref2, send_auto2, send_next2} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, "final content", :done])

      with_mock :hackney,
        get: fn
          "http://example.com/original.jpg", _headers, "", _opts ->
            send_auto1.()
            {:ok, ref1}

          "http://example.com/final.jpg", _headers, "", _opts ->
            send_auto2.()
            {:ok, ref2}
        end,
        stream_next: fn ^ref2 ->
          send_next2.()
          :ok
        end,
        close: fn _ref -> :ok end do
        result = Hackney.get("http://example.com/original.jpg", [], [])
        assert result == {:ok, "final content"}
      end
    end

    test "resolves a relative Location against the original URL" do
      {ref1, send_auto1, _send_next1} = mock_hackney_messages([{:redirect, "/final.jpg", []}])

      {ref2, send_auto2, send_next2} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, "final content", :done])

      with_mock :hackney,
        get: fn
          "http://example.com/original.jpg", _headers, "", _opts ->
            send_auto1.()
            {:ok, ref1}

          "http://example.com/final.jpg", _headers, "", _opts ->
            send_auto2.()
            {:ok, ref2}
        end,
        stream_next: fn ^ref2 ->
          send_next2.()
          :ok
        end,
        close: fn _ref -> :ok end do
        result = Hackney.get("http://example.com/original.jpg", [], [])
        assert result == {:ok, "final content"}
      end
    end

    test "strips Authorization and Cookie headers when redirecting to a different origin" do
      {ref1, send_auto1, _send_next1} =
        mock_hackney_messages([{:redirect, "https://other.example.com/final.jpg", []}])

      {ref2, send_auto2, send_next2} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, "final content", :done])

      original_headers = [
        {"authorization", "Bearer secret"},
        {"cookie", "session=abc"},
        {"accept", "*/*"}
      ]

      with_mock :hackney,
        get: fn
          "http://example.com/original.jpg", headers, "", _opts ->
            assert {"authorization", "Bearer secret"} in headers
            send_auto1.()
            {:ok, ref1}

          "https://other.example.com/final.jpg", headers, "", _opts ->
            refute Enum.any?(headers, fn {k, _v} -> String.downcase(k) == "authorization" end)
            refute Enum.any?(headers, fn {k, _v} -> String.downcase(k) == "cookie" end)
            assert {"accept", "*/*"} in headers
            send_auto2.()
            {:ok, ref2}
        end,
        stream_next: fn ^ref2 ->
          send_next2.()
          :ok
        end,
        close: fn _ref -> :ok end do
        result = Hackney.get("http://example.com/original.jpg", original_headers, [])
        assert result == {:ok, "final content"}
      end
    end

    test "keeps headers intact when redirecting within the same origin" do
      {ref1, send_auto1, _send_next1} =
        mock_hackney_messages([{:redirect, "http://example.com/final.jpg", []}])

      {ref2, send_auto2, send_next2} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, "final content", :done])

      original_headers = [{"authorization", "Bearer secret"}]

      with_mock :hackney,
        get: fn
          "http://example.com/original.jpg", _headers, "", _opts ->
            send_auto1.()
            {:ok, ref1}

          "http://example.com/final.jpg", headers, "", _opts ->
            assert {"authorization", "Bearer secret"} in headers
            send_auto2.()
            {:ok, ref2}
        end,
        stream_next: fn ^ref2 ->
          send_next2.()
          :ok
        end,
        close: fn _ref -> :ok end do
        result = Hackney.get("http://example.com/original.jpg", original_headers, [])
        assert result == {:ok, "final content"}
      end
    end

    test "gives up after max_redirect hops and returns {:error, {:too_many_redirects, count}}" do
      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          ref = make_ref()
          send(self(), {:hackney_response, ref, {:redirect, "http://example.com/loop", []}})
          {:ok, ref}
        end,
        close: fn _ref -> :ok end do
        result = Hackney.get("http://example.com/loop", [], max_redirect: 2)
        assert result == {:error, {:too_many_redirects, 2}}
      end
    end

    test "does not treat a 301 as a redirect when follow_redirect is false" do
      {ref, send_auto, _send_next} = mock_hackney_messages([{:status, 301, "Moved Permanently"}])

      with_mock :hackney,
        get: fn _url, _headers, "", opts ->
          assert Keyword.get(opts, :follow_redirect) == false
          send_auto.()
          {:ok, ref}
        end,
        close: fn ^ref -> :ok end do
        result = Hackney.get("http://example.com/file.jpg", [], follow_redirect: false)
        assert result == {:error, {:http_error, 301}}
      end
    end
  end

  describe "get/3 connection-level errors" do
    test "returns {:error, :timeout} on hackney timeout map" do
      with_mock :hackney,
        get: fn _url, _headers, "", _opts -> {:error, %{reason: :timeout}} end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, :timeout}
      end
    end

    test "returns {:error, :timeout} on the bare :connect_timeout atom (hackney 4.5.2 shape)" do
      with_mock :hackney,
        get: fn _url, _headers, "", _opts -> {:error, :connect_timeout} end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, :timeout}
      end
    end

    test "returns {:error, :timeout} on the bare :checkout_timeout atom (hackney 4.5.2 shape)" do
      with_mock :hackney,
        get: fn _url, _headers, "", _opts -> {:error, :checkout_timeout} end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, :timeout}
      end
    end

    test "returns {:error, :recv_timeout} on :timeout atom" do
      with_mock :hackney,
        get: fn _url, _headers, "", _opts -> {:error, :timeout} end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, :recv_timeout}
      end
    end

    test "returns {:error, {:http_error, reason}} on other errors" do
      with_mock :hackney,
        get: fn _url, _headers, "", _opts -> {:error, :econnrefused} end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, {:http_error, :econnrefused}}
      end
    end

    test "returns {:error, :timeout} when an error arrives instead of headers (defensive/synthetic scenario)" do
      ref = make_ref()

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send(self(), {:hackney_response, ref, {:status, 200, "OK"}})
          send(self(), {:hackney_response, ref, {:error, %{reason: :timeout}}})
          {:ok, ref}
        end,
        close: fn ^ref -> :ok end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, :timeout}
        assert_called(:hackney.close(:_))
      end
    end

    test "returns {:error, {:http_error, reason}} when an error arrives mid-body-stream" do
      {ref, send_auto, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, {:error, :closed}])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_auto.()
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          send_next.()
          :ok
        end,
        close: fn ^ref -> :ok end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, {:http_error, :closed}}
        assert_called(:hackney.close(:_))
      end
    end
  end

  describe "get/3 option passthrough" do
    test "passes recv_timeout and connect_timeout to hackney" do
      {ref, send_auto, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, "body", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", opts ->
          assert Keyword.get(opts, :recv_timeout) == 3_000
          assert Keyword.get(opts, :connect_timeout) == 8_000
          send_auto.()
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          send_next.()
          :ok
        end do
        Hackney.get("http://example.com/file.jpg", [],
          recv_timeout: 3_000,
          connect_timeout: 8_000
        )
      end
    end
  end

  describe "get/3 max_body_length enforcement" do
    test "returns {:ok, body} when body size is within max_body_length" do
      {ref, send_auto, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, "hello", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_auto.()
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          send_next.()
          :ok
        end do
        result = Hackney.get("http://example.com/file.jpg", [], max_body_length: 10)
        assert result == {:ok, "hello"}
      end
    end

    test "returns {:ok, body} when body size is exactly at max_body_length" do
      body = String.duplicate("a", 10)
      {ref, send_auto, send_next} = mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, body, :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_auto.()
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          send_next.()
          :ok
        end do
        result = Hackney.get("http://example.com/file.jpg", [], max_body_length: 10)
        assert result == {:ok, body}
      end
    end

    test "aborts the connection and returns {:error, {:http_error, :body_too_large}} when the body exceeds max_body_length" do
      big_chunk = String.duplicate("a", 20)
      {ref, send_auto, send_next} = mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, big_chunk, :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_auto.()
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          send_next.()
          :ok
        end,
        close: fn ^ref -> :ok end do
        result = Hackney.get("http://example.com/file.jpg", [], max_body_length: 10)
        assert result == {:error, {:http_error, :body_too_large}}
        assert_called(:hackney.close(:_))
      end
    end

    test "aborts as soon as the cumulative size across multiple chunks exceeds max_body_length, without requesting further chunks" do
      {ref, send_auto, send_next} =
        mock_hackney_messages([
          {:status, 200, "OK"},
          {:headers, []},
          "123456",
          "789012",
          "should-never-be-sent",
          :done
        ])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_auto.()
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          send_next.()
          :ok
        end,
        close: fn ^ref -> :ok end do
        result = Hackney.get("http://example.com/file.jpg", [], max_body_length: 10)
        assert result == {:error, {:http_error, :body_too_large}}
        assert_called(:hackney.close(:_))
      end
    end

    test "does not enforce a limit when max_body_length is :infinity (default)" do
      body = String.duplicate("a", 1_000_000)
      {ref, send_auto, send_next} = mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, body, :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_auto.()
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          send_next.()
          :ok
        end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:ok, body}
      end
    end
  end

  describe "get/3 mailbox hygiene" do
    test "flushes stray messages left in the mailbox after a 503" do
      ref = make_ref()

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send(self(), {:hackney_response, ref, {:status, 503, "Service Unavailable"}})
          send(self(), {:hackney_response, ref, {:headers, []}})
          {:ok, ref}
        end,
        close: fn ^ref -> :ok end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, :service_unavailable}
        refute_receive {:hackney_response, ^ref, _}, 50
      end
    end

    test "flushes a stray trailing message left in the mailbox after a body-too-large abort" do
      ref = make_ref()

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send(self(), {:hackney_response, ref, {:status, 200, "OK"}})
          send(self(), {:hackney_response, ref, {:headers, []}})
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          # Simulate an oversized chunk arriving together with a subsequent
          # message that we never get a chance to explicitly ask for.
          send(self(), {:hackney_response, ref, String.duplicate("a", 20)})
          send(self(), {:hackney_response, ref, :done})
          :ok
        end,
        close: fn ^ref -> :ok end do
        result = Hackney.get("http://example.com/file.jpg", [], max_body_length: 10)
        assert result == {:error, {:http_error, :body_too_large}}
        refute_receive {:hackney_response, ^ref, _}, 50
      end
    end

    test "flushes the redirect message's connection before following it" do
      {ref1, send_auto1, _send_next1} =
        mock_hackney_messages([{:redirect, "http://example.com/final.jpg", []}])

      {ref2, send_auto2, send_next2} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, "final content", :done])

      with_mock :hackney,
        get: fn
          "http://example.com/original.jpg", _headers, "", _opts ->
            send_auto1.()
            {:ok, ref1}

          "http://example.com/final.jpg", _headers, "", _opts ->
            send_auto2.()
            {:ok, ref2}
        end,
        stream_next: fn ^ref2 ->
          send_next2.()
          :ok
        end,
        close: fn _ref -> :ok end do
        result = Hackney.get("http://example.com/original.jpg", [], [])
        assert result == {:ok, "final content"}
        refute_receive {:hackney_response, ^ref1, _}, 50
      end
    end
  end

  describe "get/3 real network request (no mocks)" do
    @describetag :external

    test "fetches https://www.google.com/favicon.ico" do
      {:ok, body} = Hackney.get("https://www.google.com/favicon.ico", [], [])
      assert byte_size(body) > 0
    end
  end
end
