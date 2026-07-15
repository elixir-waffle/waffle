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
  | `:max_redirect`    | `5`          | Maximum number of redirects to follow                  |
  """

  @behaviour Waffle.HTTPClient

  @impl Waffle.HTTPClient
  def get(url, headers, options) do
    do_get(url, headers, options, 0)
  end

  defp do_get(url, headers, options, redirect_count) do
    connect_timeout = Keyword.get(options, :connect_timeout, 10_000)
    recv_timeout = Keyword.get(options, :recv_timeout, 5_000)
    follow_redirect = Keyword.get(options, :follow_redirect, true)
    max_redirect = Keyword.get(options, :max_redirect, 5)
    max_body_length = Keyword.get(options, :max_body_length, :infinity)

    hackney_options = [
      {:async, :once},
      follow_redirect: follow_redirect,
      recv_timeout: recv_timeout,
      connect_timeout: connect_timeout,
      # Force HTTP/1.1: hackney 4.5.2's HTTP/2 async response dispatch
      # (hackney_conn:h2_on_response/4, h2_on_data/4) never delivers
      # `hackney_response` messages to the caller.
      # See https://github.com/benoitc/hackney/issues/909
      protocols: [:http1]
    ]

    case :hackney.get(url, headers, "", hackney_options) do
      {:ok, ref} ->
        receive_status(
          ref,
          max_body_length,
          recv_timeout,
          url,
          headers,
          options,
          max_redirect,
          redirect_count
        )

      {:error, reason} ->
        normalize_error(reason)
    end
  end

  defp receive_status(
         ref,
         max_body_length,
         recv_timeout,
         url,
         headers,
         options,
         max_redirect,
         redirect_count
       ) do
    receive do
      {:hackney_response, ^ref, {:status, 200, _reason}} ->
        receive_headers(ref, max_body_length, recv_timeout)

      {:hackney_response, ^ref, {:status, 503, _reason}} ->
        close_and_flush(ref)
        {:error, :service_unavailable}

      {:hackney_response, ^ref, {:redirect, location, _response_headers}} ->
        follow_redirect(ref, url, location, headers, options, max_redirect, redirect_count)

      {:hackney_response, ^ref, {:see_other, location, _response_headers}} ->
        follow_redirect(ref, url, location, headers, options, max_redirect, redirect_count)

      {:hackney_response, ^ref, {:status, status, _reason}} ->
        close_and_flush(ref)
        {:error, {:http_error, status}}

      {:hackney_response, ^ref, {:error, reason}} ->
        close_and_flush(ref)
        normalize_error(reason)
    after
      recv_timeout ->
        close_and_flush(ref)
        {:error, :recv_timeout}
    end
  end

  defp follow_redirect(ref, url, location, headers, options, max_redirect, redirect_count) do
    close_and_flush(ref)

    if redirect_count >= max_redirect do
      {:error, {:too_many_redirects, redirect_count}}
    else
      new_url = resolve_redirect_url(url, location)
      new_headers = strip_sensitive_headers_on_cross_origin(url, new_url, headers)
      do_get(new_url, new_headers, options, redirect_count + 1)
    end
  end

  defp resolve_redirect_url(url, location) do
    location = to_string(location)

    url
    |> URI.merge(location)
    |> URI.to_string()
  end

  # Mirrors hackney's own CVE-2018-1000007 mitigation for its sync client:
  # don't forward credentials to a different host on redirect.
  defp strip_sensitive_headers_on_cross_origin(url, new_url, headers) do
    if same_origin?(url, new_url) do
      headers
    else
      Enum.reject(headers, fn {key, _value} ->
        String.downcase(to_string(key)) in ["authorization", "cookie"]
      end)
    end
  end

  defp same_origin?(url, new_url) do
    a = URI.parse(url)
    b = URI.parse(new_url)
    {a.scheme, a.host, a.port} == {b.scheme, b.host, b.port}
  end

  defp receive_headers(ref, max_body_length, recv_timeout) do
    receive do
      {:hackney_response, ^ref, {:headers, response_headers}} ->
        :hackney.stream_next(ref)
        receive_body(ref, response_headers, [], 0, max_body_length, recv_timeout)

      {:hackney_response, ^ref, {:error, reason}} ->
        close_and_flush(ref)
        normalize_error(reason)
    after
      recv_timeout ->
        close_and_flush(ref)
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
          close_and_flush(ref)
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
        close_and_flush(ref)
        normalize_error(reason)
    after
      recv_timeout ->
        close_and_flush(ref)
        {:error, :recv_timeout}
    end
  end

  defp build_response(body, response_headers) do
    filename =
      :hackney_headers.new(response_headers)
      |> get_content_disposition_filename()

    if filename, do: {:ok, body, filename}, else: {:ok, body}
  end

  # Closes the connection and drains any `{:hackney_response, ^ref, _}`
  # messages already sitting in our mailbox. Hackney can push multiple
  # messages (e.g. status + headers, or a trailing chunk) before we act on
  # an error/abort, and without this a long-lived process (e.g. a GenServer
  # calling into Waffle) would accumulate stray `handle_info` messages.
  defp close_and_flush(ref) do
    :hackney.close(ref)
    flush_messages(ref)
  end

  defp flush_messages(ref) do
    receive do
      {:hackney_response, ^ref, _msg} -> flush_messages(ref)
    after
      0 -> :ok
    end
  end

  # connect/checkout timeout: hackney returns %{reason: :timeout} (older
  # shape) or the bare atoms :connect_timeout / :checkout_timeout (4.5.2)
  defp normalize_error(%{reason: :timeout}), do: {:error, :timeout}
  defp normalize_error(:connect_timeout), do: {:error, :timeout}
  defp normalize_error(:checkout_timeout), do: {:error, :timeout}
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
