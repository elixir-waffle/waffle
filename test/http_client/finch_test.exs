if Code.ensure_loaded?(Finch) do
  defmodule WaffleTest.HTTPClient.Finch do
    use ExUnit.Case, async: false
    import Mock

    defp simulate_stream(acc, fun, status, headers, body_chunks) do
      {:cont, acc} = fun.({:status, status}, acc)
      {:cont, acc} = fun.({:headers, headers}, acc)

      Enum.reduce_while(body_chunks, {:ok, acc}, fn chunk, {:ok, acc} ->
        case fun.({:data, chunk}, acc) do
          {:cont, acc} -> {:cont, {:ok, acc}}
          {:halt, acc} -> {:halt, {:ok, acc}}
        end
      end)
    end

    describe "get/3" do
      test "returns {:ok, body} on 200 with no content-disposition header" do
        with_mock Finch, [:passthrough],
          stream_while: fn _req, _pool, acc, fun, _opts ->
            simulate_stream(acc, fun, 200, [], ["file content"])
          end do
          result = Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], [])
          assert result == {:ok, "file content"}
        end
      end

      test "returns {:ok, body, filename} when content-disposition header is present" do
        headers = [{"content-disposition", ~s(attachment; filename="photo.jpg")}]

        with_mock Finch, [:passthrough],
          stream_while: fn _req, _pool, acc, fun, _opts ->
            simulate_stream(acc, fun, 200, headers, ["file content"])
          end do
          result = Waffle.HTTPClient.Finch.get("http://example.com/file", [], [])
          assert result == {:ok, "file content", "photo.jpg"}
        end
      end

      test "returns {:error, {:http_error, :body_too_large}} when body exceeds max_body_length" do
        with_mock Finch, [:passthrough],
          stream_while: fn _req, _pool, acc, fun, _opts ->
            simulate_stream(acc, fun, 200, [], ["long body"])
          end do
          result =
            Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], max_body_length: 4)

          assert result == {:error, {:http_error, :body_too_large}}
        end
      end

      test "returns {:error, :service_unavailable} on 503" do
        with_mock Finch, [:passthrough],
          stream_while: fn _req, _pool, acc, fun, _opts ->
            simulate_stream(acc, fun, 503, [], [])
          end do
          result = Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], [])
          assert result == {:error, :service_unavailable}
        end
      end

      test "returns {:error, {:http_error, {:unexpected_status, status}}} on non-200/503 status" do
        with_mock Finch, [:passthrough],
          stream_while: fn _req, _pool, acc, fun, _opts ->
            simulate_stream(acc, fun, 404, [], [])
          end do
          result = Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], [])
          assert result == {:error, {:http_error, {:unexpected_status, 404}}}
        end
      end

      test "returns {:error, :timeout} on timeout" do
        with_mock Finch, [:passthrough],
          stream_while: fn _req, _pool, acc, _fun, _opts ->
            {:error, %Mint.TransportError{reason: :timeout}, acc}
          end do
          result = Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], [])
          assert result == {:error, :timeout}
        end
      end

      test "returns {:error, {:http_error, reason}} on other transport errors" do
        with_mock Finch, [:passthrough],
          stream_while: fn _req, _pool, acc, _fun, _opts ->
            {:error, %Mint.TransportError{reason: :econnrefused}, acc}
          end do
          result = Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], [])
          assert result == {:error, {:http_error, %Mint.TransportError{reason: :econnrefused}}}
        end
      end

      test "passes recv_timeout as receive_timeout to Finch" do
        with_mock Finch, [:passthrough],
          stream_while: fn _req, _pool, acc, fun, opts ->
            assert Keyword.get(opts, :receive_timeout) == 3_000
            simulate_stream(acc, fun, 200, [], ["body"])
          end do
          Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], recv_timeout: 3_000)
        end
      end

      test "uses configured pool_name" do
        Application.put_env(:waffle, Waffle.HTTPClient.Finch, pool_name: MyApp.Finch)

        on_exit(fn -> Application.delete_env(:waffle, Waffle.HTTPClient.Finch) end)

        with_mock Finch, [:passthrough],
          stream_while: fn _req, pool, acc, fun, _opts ->
            assert pool == MyApp.Finch
            simulate_stream(acc, fun, 200, [], ["body"])
          end do
          Waffle.HTTPClient.Finch.get("http://example.com/file.jpg", [], [])
        end
      end
    end
  end
end
