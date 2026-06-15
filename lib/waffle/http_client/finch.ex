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
  | `:connect_timeout` | `10_000`     | Timeout for establishing a connection, in milliseconds |
  | `:max_body_length` | `:infinity`  | Maximum response body size, in bytes                   |
  """

  @behaviour Waffle.HTTPClient

  @impl Waffle.HTTPClient
  def get(url, headers, options) do
    finch_config = Application.get_env(:waffle, Waffle.HTTPClient.Finch, [])
    finch_name = Keyword.get(finch_config, :pool_name, Waffle.Finch)
    recv_timeout = Keyword.get(options, :recv_timeout, 5_000)
    connect_timeout = Keyword.get(options, :connect_timeout, 10_000)
    max_body_length = Keyword.get(options, :max_body_length, :infinity)

    finch_options = [
      receive_timeout: recv_timeout,
      connect_options: [timeout: connect_timeout]
    ]

    request = Finch.build(:get, url, headers)

    case Finch.request(request, finch_name, finch_options) do
      {:ok, %Finch.Response{status: 200, headers: response_headers, body: body}} ->
        handle_success(body, response_headers, max_body_length)

      {:ok, %Finch.Response{status: 503}} ->
        {:error, :service_unavailable}

      {:ok, %Finch.Response{}} ->
        {:error, {:http_error, :unexpected_status}}

      {:error, reason} ->
        classify_error(reason)
    end
  end

  defp handle_success(body, response_headers, max_body_length) do
    if over_limit?(body, max_body_length) do
      {:error, {:http_error, :body_too_large}}
    else
      filename = find_content_disposition_filename(response_headers)
      if filename, do: {:ok, body, filename}, else: {:ok, body}
    end
  end

  defp classify_error(%{reason: :timeout}), do: {:error, :timeout}

  defp classify_error(exception) when is_exception(exception),
    do: {:error, {:http_error, exception}}

  defp classify_error(reason), do: {:error, {:http_error, reason}}

  defp over_limit?(_body, :infinity), do: false
  defp over_limit?(body, max), do: byte_size(body) > max

  defp find_content_disposition_filename(headers) do
    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(key) == "content-disposition" do
        Waffle.HTTPClient.parse_content_disposition(value)
      end
    end)
  end
end
