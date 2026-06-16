defmodule Waffle.HTTPClient.Hackney do
  @moduledoc """
  Default HTTP client implementation using `:hackney`.

  Add `:hackney` to your dependencies:

      {:hackney, "~> 1.9"}

  ## Configuration

      config :waffle, :http_client, Waffle.HTTPClient.Hackney

  ## Options

  | Option             | Default      | Description                                            |
  |--------------------|--------------|--------------------------------------------------------|
  | `:recv_timeout`    | `5_000`      | Timeout for receiving a response, in milliseconds      |
  | `:connect_timeout` | `10_000`     | Timeout for establishing a connection, in milliseconds |
  | `:max_body_length` | `:infinity`  | Maximum response body size, in bytes                   |
  """

  @behaviour Waffle.HTTPClient

  @impl Waffle.HTTPClient
  def get(url, headers, options) do
    hackney_options = [
      follow_redirect: Keyword.get(options, :follow_redirect, true),
      recv_timeout: Keyword.get(options, :recv_timeout, 5_000),
      connect_timeout: Keyword.get(options, :connect_timeout, 10_000)
    ]

    max_body_length = Keyword.get(options, :max_body_length, :infinity)

    with {:ok, 200, response_headers, client_ref} <-
           :hackney.get(url, headers, "", hackney_options),
         {:ok, body} <- :hackney.body(client_ref, max_body_length) do
      filename =
        :hackney_headers.new(response_headers)
        |> get_content_disposition_filename()

      if filename, do: {:ok, body, filename}, else: {:ok, body}
    else
      {:ok, 503, _headers, client_ref} ->
        :hackney.close(client_ref)
        {:error, :service_unavailable}

      {:ok, _status, _headers, client_ref} ->
        :hackney.close(client_ref)
        {:error, {:http_error, :unexpected_status}}

      # hackney returns a map for connect timeout and a bare atom for recv timeout
      {:error, %{reason: :timeout}} ->
        {:error, :timeout}

      {:error, :timeout} ->
        {:error, :recv_timeout}

      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  defp get_content_disposition_filename(headers) do
    case :hackney_headers.get_value("content-disposition", headers) do
      :undefined -> nil
      value -> Waffle.HTTPClient.parse_content_disposition(value)
    end
  end
end
