defmodule Waffle.HTTPClient.Hackney do
  @moduledoc """
  Default HTTP client implementation using `:hackney`.

  Add `:hackney` to your dependencies:

      {:hackney, "~> 4.5.2"}

  ## Configuration

      config :waffle, :http_client, Waffle.HTTPClient.Hackney

  ## Options

  | Option             | Default      | Description                                            |
  |--------------------|--------------|--------------------------------------------------------|
  | `:recv_timeout`    | `5_000`      | Timeout for receiving a response, in milliseconds      |
  | `:connect_timeout` | `10_000`     | Timeout for establishing a connection, in milliseconds |
  | `:max_body_length` | `:infinity`  | Maximum response body size, in bytes                   |
  | `:follow_redirect` | `true`       | Whether to follow HTTP redirects automatically         |
  """

  @behaviour Waffle.HTTPClient

  @impl Waffle.HTTPClient
  def get(url, headers, options) do
    connect_timeout = Keyword.get(options, :connect_timeout, 10_000)
    recv_timeout = Keyword.get(options, :recv_timeout, 5_000)

    hackney_options = [
      {:async, :once},
      follow_redirect: Keyword.get(options, :follow_redirect, true),
      recv_timeout: recv_timeout,
      connect_timeout: connect_timeout,
      # Force HTTP/1.1: hackney 4.5.2's HTTP/2 async response dispatch
      # (hackney_conn:h2_on_response/4, h2_on_data/4) never delivers
      # `hackney_response` messages to the caller.
      # See https://github.com/benoitc/hackney/issues/909
      protocols: [:http1]
    ]

    max_body_length = Keyword.get(options, :max_body_length, :infinity)

    case :hackney.get(url, headers, "", hackney_options) do
      {:ok, ref} ->
        receive_status(ref, max_body_length, recv_timeout)

      {:error, reason} ->
        normalize_error(reason)
    end
  end

  defp receive_status(ref, max_body_length, recv_timeout) do
    receive do
      {:hackney_response, ^ref, {:status, 200, _reason}} ->
        :hackney.stream_next(ref)
        receive_headers(ref, max_body_length, recv_timeout)

      {:hackney_response, ^ref, {:status, 503, _reason}} ->
        :hackney.close(ref)
        {:error, :service_unavailable}

      {:hackney_response, ^ref, {:status, status, _reason}} ->
        :hackney.close(ref)
        {:error, {:http_error, status}}

      {:hackney_response, ^ref, {:error, reason}} ->
        normalize_error(reason)
    after
      recv_timeout ->
        :hackney.close(ref)
        {:error, :recv_timeout}
    end
  end

  defp receive_headers(ref, max_body_length, recv_timeout) do
    receive do
      {:hackney_response, ^ref, {:headers, response_headers}} ->
        :hackney.stream_next(ref)
        receive_body(ref, response_headers, [], 0, max_body_length, recv_timeout)

      {:hackney_response, ^ref, {:error, reason}} ->
        :hackney.close(ref)
        normalize_error(reason)
    after
      recv_timeout ->
        :hackney.close(ref)
        {:error, :recv_timeout}
    end
  end

  defp receive_body(ref, response_headers, acc, size, max_body_length, recv_timeout) do
    receive do
      {:hackney_response, ^ref, :done} ->
        body = acc |> Enum.reverse() |> IO.iodata_to_binary()
        build_response(body, response_headers)

      {:hackney_response, ^ref, chunk} when is_binary(chunk) ->
        new_size = size + byte_size(chunk)

        if max_body_length != :infinity and new_size > max_body_length do
          :hackney.close(ref)
          {:error, {:http_error, :body_too_large}}
        else
          :hackney.stream_next(ref)

          receive_body(
            ref,
            response_headers,
            [chunk | acc],
            new_size,
            max_body_length,
            recv_timeout
          )
        end

      {:hackney_response, ^ref, {:error, reason}} ->
        :hackney.close(ref)
        normalize_error(reason)
    after
      recv_timeout ->
        :hackney.close(ref)
        {:error, :recv_timeout}
    end
  end

  defp build_response(body, response_headers) do
    filename =
      :hackney_headers.new(response_headers)
      |> get_content_disposition_filename()

    if filename, do: {:ok, body, filename}, else: {:ok, body}
  end

  # connect timeout: hackney returns %{reason: :timeout}, not a bare atom
  defp normalize_error(%{reason: :timeout}), do: {:error, :timeout}
  # recv timeout: hackney returns a bare :timeout atom
  defp normalize_error(:timeout), do: {:error, :recv_timeout}
  defp normalize_error(reason), do: {:error, {:http_error, reason}}

  defp get_content_disposition_filename(headers) do
    case :hackney_headers.get_value("content-disposition", headers) do
      :undefined ->
        nil

      value when is_binary(value) ->
        Waffle.HTTPClient.ContentDisposition.filename(value)

      _ ->
        nil
    end
  end
end
