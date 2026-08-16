defmodule Waffle.HTTPClient.Request do
  @moduledoc """
  Configures requests used to download remote files.

  These settings apply only when Waffle fetches a remote URL. They do not affect
  requests made by storage adapters such as `Waffle.Storage.S3`.

  ## Configuration

  Override the defaults with:

      config :waffle,
        request: [
          max_redirects: 3,
          max_retries: 3,
          receive_timeout_ms: 5_000,
          connect_timeout_ms: 10_000,
          max_body_length_bytes: 50 * 1024,
          backoff_factor_ms: 1_000,
          backoff_max_ms: 30_000
        ]

  The values shown above are the defaults.

  ## Options

    * `:max_redirects` - maximum number of redirects to follow. Set to `nil` to
      disable redirects.
    * `:max_retries` - number of retries after the initial request. Waffle retries
      timeouts and HTTP `503` responses.
    * `:receive_timeout_ms` - socket receive timeout, in milliseconds.
    * `:connect_timeout_ms` - connection timeout, in milliseconds.
    * `:max_body_length_bytes` - maximum response body size, in bytes. Set to
      `nil` to disable the limit.
    * `:backoff_factor_ms` - initial exponential-backoff delay, in milliseconds.
    * `:backoff_max_ms` - maximum exponential-backoff delay, in milliseconds.
  """

  alias Waffle.HTTPClient.{Error, Response}

  @default [
    max_redirects: 3,
    max_retries: 3,
    receive_timeout_ms: 5_000,
    connect_timeout_ms: 10_000,
    max_body_length_bytes: 50 * 1024,
    backoff_factor_ms: 1_000,
    backoff_max_ms: 30_000
  ]

  @spec options() :: Waffle.HTTPClient.options()
  def options do
    config = Application.get_env(:waffle, :request, [])

    Keyword.merge(@default, config)
  end

  @spec download(String.t(), Waffle.HTTPClient.url(), Waffle.HTTPClient.headers()) ::
          :ok
          | :error
          | {:ok, Waffle.HTTPClient.filename()}
          | {:error, File.posix() | Waffle.HTTPClient.error_response()}
  def download(local_path, url, headers \\ []) do
    case request(url, headers, options()) do
      {:ok, body} ->
        File.write(local_path, body)

      {:ok, body, filename} ->
        case File.write(local_path, body) do
          :ok -> {:ok, filename}
          _ -> :error
        end

      {:error, _reason} = err ->
        err
    end
  end

  defp request(url, headers, options, tries \\ 0) do
    case http_client().get(url, headers, options) do
      {:ok, %Response{body: body, filename: nil}} ->
        {:ok, body}

      {:ok, %Response{body: body, filename: filename}} ->
        {:ok, body, filename}

      {:error, %Error{error: error_type} = error}
      when error_type in [:timeout, {:unexpected_status, 503}] ->
        case retry(tries, options) do
          {:ok, :retry} -> request(url, headers, options, tries + 1)
          {:error, :out_of_tries} -> {:error, error}
        end

      {:error, _} = err ->
        err
    end
  end

  defp retry(tries, options) do
    if tries < options[:max_retries] do
      backoff = round(options[:backoff_factor_ms] * :math.pow(2, tries))
      backoff = :erlang.min(backoff, options[:backoff_max_ms])
      :timer.sleep(backoff)
      {:ok, :retry}
    else
      {:error, :out_of_tries}
    end
  end

  defp http_client do
    Application.fetch_env!(:waffle, :http_client)
  end
end
