defmodule Waffle.HTTPClient.Req do
  @moduledoc """
  HTTP client implementation using [Req](https://hex.pm/packages/req).

  Add `:req` to your dependencies:

      {:req, "~> 0.5"}

  ## Configuration

      config :waffle, :http_client, Waffle.HTTPClient.Req

  ## Options

  | Option             | Default      | Description                                            |
  |--------------------|--------------|--------------------------------------------------------|
  | `:recv_timeout`    | `5_000`      | Timeout for receiving a response, in milliseconds      |
  | `:connect_timeout` | `10_000`     | Timeout for establishing a connection, in milliseconds |
  | `:max_body_length` | `:infinity`  | Maximum response body size, in bytes                   |
  | `:follow_redirect` | `true`       | Whether to follow HTTP redirects automatically         |

  ## Passing additional req options

  Additional options are merged into every request, letting you tune the
  connection pool, add default headers, and so on:

      config :waffle, Waffle.HTTPClient.Req,
        req_options: [pool_timeout: 10_000]
  """

  @behaviour Waffle.HTTPClient

  alias Waffle.ContentDisposition

  @impl Waffle.HTTPClient
  def get(url, headers, options) do
    max_body_length = Keyword.get(options, :max_body_length, :infinity)

    url
    |> build_request(headers, options, max_body_length)
    |> Req.request()
    |> handle_response()
  end

  defp build_request(url, headers, options, max_body_length) do
    [
      url: url,
      headers: headers,
      raw: true,
      retry: false,
      redirect: Keyword.get(options, :follow_redirect, true),
      receive_timeout: Keyword.get(options, :recv_timeout, 5_000),
      connect_options: [timeout: Keyword.get(options, :connect_timeout, 10_000)]
    ]
    |> maybe_limit_body(max_body_length)
    |> Keyword.merge(extra_options())
    |> Req.new()
  end

  defp maybe_limit_body(opts, :infinity), do: opts

  defp maybe_limit_body(opts, max) when is_integer(max) do
    Keyword.put(opts, :into, body_collector(max))
  end

  defp body_collector(max) do
    fn {:data, chunk}, {req, resp} ->
      body = (resp.body || "") <> chunk
      resp = %{resp | body: body}

      if byte_size(body) > max do
        {:halt, {req, Req.Response.put_private(resp, :waffle_body_exceeded, true)}}
      else
        {:cont, {req, resp}}
      end
    end
  end

  defp extra_options do
    :waffle
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:req_options, [])
  end

  defp handle_response({:ok, %Req.Response{status: 200} = resp}) do
    if Req.Response.get_private(resp, :waffle_body_exceeded) do
      {:error, {:http_error, :max_body_length_exceeded}}
    else
      case filename(resp) do
        nil -> {:ok, resp.body}
        filename -> {:ok, resp.body, filename}
      end
    end
  end

  defp handle_response({:ok, %Req.Response{status: 503}}) do
    {:error, :service_unavailable}
  end

  defp handle_response({:ok, %Req.Response{status: status}}) do
    {:error, {:http_error, status}}
  end

  defp handle_response({:error, %Req.TooManyRedirectsError{}}) do
    {:error, {:http_error, :too_many_redirects}}
  end

  defp handle_response({:error, %{reason: :timeout}}) do
    {:error, :timeout}
  end

  defp handle_response({:error, %{reason: reason}}) do
    {:error, {:http_error, reason}}
  end

  defp handle_response({:error, error}) do
    {:error, {:http_error, error}}
  end

  defp filename(resp) do
    resp
    |> Req.Response.get_header("content-disposition")
    |> List.first()
    |> ContentDisposition.filename()
  end
end
