defmodule WaffleTest.HTTPClient.Hackney do
  use ExUnit.Case, async: false
  import Mock

  alias Waffle.HTTPClient.Hackney

  # To simulate a real connection in these tests we queue up the exact sequence
  # of `hackney_response` messages it would send (status, headers, body chunk(s), :done)
  # and pop one off the queue each time `:hackney.get/4` or `:hackney.stream_next/1`
  # is invoked
  defp mock_hackney_messages(messages) do
    ref = make_ref()
    test_pid = self()
    {:ok, agent} = Agent.start_link(fn -> messages end)

    send_next = fn ->
      # credo:disable-for-next-line Credo.Check.Refactor.Nesting
      case Agent.get_and_update(agent, fn
             [next | rest] -> {next, rest}
             [] -> {nil, []}
           end) do
        nil -> :ok
        msg -> send(test_pid, {:hackney_response, ref, msg})
      end
    end

    {ref, send_next}
  end

  describe "get/3 successful responses" do
    test "returns {:ok, body} on 200 with no content-disposition header" do
      {ref, send_next} = mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, "file content", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", opts ->
          assert {:async, :once} in opts
          send_next.()
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

      {ref, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, response_headers}, "file content", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_next.()
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

      {ref, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, response_headers}, "file content", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_next.()
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

      {ref, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, response_headers}, "file content", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_next.()
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

      {ref, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, response_headers}, "file content", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_next.()
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

      {ref, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, response_headers}, "file content", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_next.()
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
      {ref, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, "ab", "cd", "ef", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_next.()
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
      {ref, send_next} = mock_hackney_messages([{:status, 503, "Service Unavailable"}])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_next.()
          {:ok, ref}
        end,
        close: fn ^ref -> :ok end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, :service_unavailable}
        assert_called(:hackney.close(:_))
      end
    end

    test "returns {:error, {:http_error, status}} with the actual HTTP status on non-200/503 and closes the connection" do
      {ref, send_next} = mock_hackney_messages([{:status, 404, "Not Found"}])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_next.()
          {:ok, ref}
        end,
        close: fn ^ref -> :ok end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, {:http_error, 404}}
        assert_called(:hackney.close(:_))
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

    test "returns {:error, :timeout} when an error arrives while waiting on headers (connect-timeout shape)" do
      {ref, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:error, %{reason: :timeout}}])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_next.()
          {:ok, ref}
        end,
        stream_next: fn ^ref ->
          send_next.()
          :ok
        end,
        close: fn ^ref -> :ok end do
        result = Hackney.get("http://example.com/file.jpg", [], [])
        assert result == {:error, :timeout}
        assert_called(:hackney.close(:_))
      end
    end

    test "returns {:error, {:http_error, reason}} when an error arrives mid-body-stream" do
      {ref, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, {:error, :closed}])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_next.()
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
      {ref, send_next} = mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, "body", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", opts ->
          assert Keyword.get(opts, :recv_timeout) == 3_000
          assert Keyword.get(opts, :connect_timeout) == 8_000
          send_next.()
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
      {ref, send_next} =
        mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, "hello", :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_next.()
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
      {ref, send_next} = mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, body, :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_next.()
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
      {ref, send_next} = mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, big_chunk, :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_next.()
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
      {ref, send_next} =
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
          send_next.()
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
      {ref, send_next} = mock_hackney_messages([{:status, 200, "OK"}, {:headers, []}, body, :done])

      with_mock :hackney,
        get: fn _url, _headers, "", _opts ->
          send_next.()
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

  describe "get/3 real network request (no mocks)" do
    test "fetches https://www.google.com/favicon.ico" do
      {:ok, body} = Hackney.get("https://www.google.com/favicon.ico", [], [])
      assert byte_size(body) > 0
    end
  end
end
