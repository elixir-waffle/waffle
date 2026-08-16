defmodule Waffle.HTTPClient.Request do
  @moduledoc false

  @default [
    max_redirects: 3,
    max_retries: 3,
    receive_timeout_ms: 5_000,
    connect_timeout_ms: 10_000,
    max_body_length_bytes: 50 * 1024,
    backoff_factor_ms: 1_000,
    backoff_max_ms: 30_000
  ]

  def options do
    config = Application.get_env(:waffle, :request, [])

    Keyword.merge(@default, config)
  end
end
