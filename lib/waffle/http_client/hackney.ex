defmodule Waffle.HTTPClient.Hackney do
  @moduledoc """
  Default HTTP client implementation using `:hackney`.

  Add `:hackney` to your dependencies:

      {:hackney, "~> 4.0"}

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
    hackney_options = [
      follow_redirect: Keyword.get(options, :follow_redirect, true),
      recv_timeout: Keyword.get(options, :recv_timeout, 5_000),
      connect_timeout: Keyword.get(options, :connect_timeout, 10_000)
    ]

    case :hackney.get(url, headers, "", hackney_options) do
      {:ok, 200, response_headers, body} ->
        filename =
          :hackney_headers.new(response_headers)
          |> get_content_disposition_filename()

        if filename, do: {:ok, body, filename}, else: {:ok, body}

      {:ok, 503, _headers, _body} ->
        {:error, :service_unavailable}

      {:ok, status, _headers, _body} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        normalize_error(reason)
    end
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

      value ->
        case :hackney_headers.content_disposition(value) do
          {_, [{"filename", filename} | _]} -> filename
          _ -> nil
        end
    end
  end
end
