if Code.ensure_loaded?(Finch) do
  defmodule Waffle.HTTPClient.Finch do
    @moduledoc """
    HTTP client implementation using `Finch`.

    ## Setup

    Add `finch` to your dependencies:

        {:finch, "~> 0.18"}

    Start a `Finch` pool in your application supervision tree:

        children = [
          {Finch, name: MyApp.Finch}
        ]

    Then configure Waffle to use this client and point it at your pool:

        config :waffle, :http_client, Waffle.HTTPClient.Finch
        config :waffle, Waffle.HTTPClient.Finch, pool_name: MyApp.Finch

    ## Options

    | Option             | Default      | Description                                            |
    |--------------------|--------------|--------------------------------------------------------|
    | `:recv_timeout`    | `5_000`      | Timeout for receiving a response, in milliseconds      |
    | `:max_body_length` | `:infinity`  | Maximum response body size, in bytes                   |
    | `:max_redirects`   | `5`          | Maximum number of redirects to follow (`0` disables)   |

    > #### Unsupported options {: .info}
    >
    > - `:connect_timeout` — not supported; configure connection settings (e.g. timeouts, TLS) at pool startup via `Finch.start_link/1`
    > - `:follow_redirect` — not supported as a boolean; use `:max_redirects` to control redirect behaviour (set to `0` to disable)
    """

    @behaviour Waffle.HTTPClient

    @impl Waffle.HTTPClient
    def get(url, headers, options) do
      finch_config = Application.get_env(:waffle, Waffle.HTTPClient.Finch, [])
      finch_name = Keyword.get(finch_config, :pool_name, Waffle.Finch)
      recv_timeout = Keyword.get(options, :recv_timeout, 5_000)
      max_body_length = Keyword.get(options, :max_body_length, :infinity)

      finch_options = [receive_timeout: recv_timeout]

      request = Finch.build(:get, url, headers)
      acc = %{status: nil, headers: [], body: [], bytes: 0}

      try do
        request
        |> Finch.stream_while(finch_name, acc, stream_fun(max_body_length), finch_options)
        |> handle_result(url, headers, options)
      rescue
        exception -> {:error, {:http_error, exception}}
      end
    end

    defp stream_fun(max_body_length) do
      fn
        {:status, s}, acc -> {:cont, %{acc | status: s}}
        {:headers, h}, acc -> {:cont, %{acc | headers: h}}
        {:trailers, _}, acc -> {:cont, acc}
        {:data, chunk}, acc -> accumulate_chunk(chunk, acc, max_body_length)
      end
    end

    defp accumulate_chunk(chunk, acc, max_body_length) do
      new_bytes = acc.bytes + byte_size(chunk)

      if max_body_length != :infinity and new_bytes > max_body_length,
        do: {:halt, %{acc | body: :over_limit}},
        else: {:cont, %{acc | body: [chunk | acc.body], bytes: new_bytes}}
    end

    defp handle_result({:ok, %{status: 200, body: :over_limit}}, _url, _headers, _options) do
      {:error, {:http_error, :body_too_large}}
    end

    defp handle_result(
           {:ok, %{status: 200, headers: resp_headers, body: parts}},
           _url,
           _headers,
           _options
         ) do
      body = parts |> Enum.reverse() |> IO.iodata_to_binary()
      filename = find_content_disposition_filename(resp_headers)
      if filename, do: {:ok, body, filename}, else: {:ok, body}
    end

    defp handle_result({:ok, %{status: 503}}, _url, _headers, _options) do
      {:error, :service_unavailable}
    end

    defp handle_result({:ok, %{status: status, headers: resp_headers}}, url, headers, options)
         when status in 300..399 do
      max_redirects = Keyword.get(options, :max_redirects, 5)

      if max_redirects == 0 do
        {:error, {:http_error, :too_many_redirects}}
      else
        case List.keyfind(resp_headers, "location", 0) do
          {_, location} ->
            new_url = url |> URI.merge(location) |> URI.to_string()
            get(new_url, headers, Keyword.put(options, :max_redirects, max_redirects - 1))

          nil ->
            {:error, {:http_error, {:unexpected_status, status}}}
        end
      end
    end

    defp handle_result({:ok, %{status: status}}, _url, _headers, _options) do
      {:error, {:http_error, {:unexpected_status, status}}}
    end

    defp handle_result({:error, reason, _acc}, _url, _headers, _options) do
      classify_error(reason)
    end

    defp classify_error(%{reason: :timeout}), do: {:error, :timeout}

    defp classify_error(exception) when is_exception(exception),
      do: {:error, {:http_error, exception}}

    defp classify_error(reason), do: {:error, {:http_error, reason}}

    defp find_content_disposition_filename(headers) do
      Enum.find_value(headers, fn {key, value} ->
        if String.downcase(key) == "content-disposition" do
          Waffle.HTTPClient.parse_content_disposition(value)
        end
      end)
    end
  end
end
