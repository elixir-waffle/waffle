if Code.ensure_loaded?(:hackney) do
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

      max_body_length = Keyword.get(options, :max_body_length, :infinity)

      case :hackney.get(url, headers, "", hackney_options) do
        {:ok, 200, response_headers, client_ref} ->
          read_body(client_ref, response_headers, max_body_length)

        {:ok, 503, _headers, client_ref} ->
          :hackney.close(client_ref)
          {:error, :service_unavailable}

        {:ok, status, _headers, client_ref} ->
          :hackney.close(client_ref)
          {:error, {:http_error, status}}

        {:error, reason} ->
          normalize_error(reason)
      end
    end

    defp read_body(client_ref, response_headers, max_body_length) do
      case :hackney.body(client_ref, max_body_length) do
        {:ok, body} ->
          filename = find_content_disposition_filename(response_headers)
          if filename, do: {:ok, body, filename}, else: {:ok, body}

        {:error, reason} ->
          :hackney.close(client_ref)
          normalize_error(reason)
      end
    end

    # connect timeout: hackney returns %{reason: :timeout}, not a bare atom
    defp normalize_error(%{reason: :timeout}), do: {:error, :timeout}
    # recv timeout: hackney returns a bare :timeout atom
    defp normalize_error(:timeout), do: {:error, :recv_timeout}
    defp normalize_error(reason), do: {:error, {:http_error, reason}}

    defp find_content_disposition_filename(headers) do
      Enum.find_value(headers, fn {key, value} ->
        if String.downcase(key) == "content-disposition" do
          Waffle.HTTPClient.parse_content_disposition(value)
        end
      end)
    end
  end
else
  defmodule Waffle.HTTPClient.Hackney do
    @moduledoc false

    @behaviour Waffle.HTTPClient

    @impl Waffle.HTTPClient
    def get(_url, _headers, _options) do
      raise """
      Waffle.HTTPClient.Hackney is configured but the :hackney dependency is not \
      loaded.

      Add it to your deps:

          {:hackney, "~> 1.9"}

      Or configure a different HTTP client, e.g.:

          config :waffle, :http_client, Waffle.HTTPClient.Finch
      """
    end
  end
end
