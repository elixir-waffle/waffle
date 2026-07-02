defmodule Waffle.HTTPClient do
  @moduledoc """
  Behaviour for pluggable HTTP clients used when downloading remote files.

  ## Built-in implementations

  - `Waffle.HTTPClient.Hackney` — default, uses `:hackney`. Add `{:hackney, "~> 1.9"}` to
    your deps.

  ## Configuration

      config :waffle, :http_client, Waffle.HTTPClient.Hackney

  ## Writing a custom client

  Implement the `c:get/3` callback and configure Waffle to use your module:

      config :waffle, :http_client, MyApp.HTTPClient

  ### Options

  Waffle passes the following options (all values come from application config):

  | Option             | Type                    | Default    | Description                              |
  |--------------------|-------------------------|------------|------------------------------------------|
  | `:recv_timeout`    | `non_neg_integer()`              | `5_000`     | Timeout for receiving a response (ms)              |
  | `:connect_timeout` | `non_neg_integer()`              | `10_000`    | Timeout for establishing a connection (ms)         |
  | `:max_body_length` | `non_neg_integer() \| :infinity` | `:infinity` | Maximum allowed response body size (bytes)         |
  | `:follow_redirect` | `boolean()`                      | `true`      | Whether to follow HTTP redirects                   |

  ### Return values

  | Pattern                                | Meaning                                          |
  |----------------------------------------|--------------------------------------------------|
  | `{:ok, body}`                          | Successful response, no filename in headers      |
  | `{:ok, body, filename}`                | Successful response with `content-disposition` filename |
  | `{:error, :timeout}`                   | Connect timed out — Waffle will retry            |
  | `{:error, :recv_timeout}`              | Receive timed out — Waffle will retry            |
  | `{:error, :service_unavailable}`       | Server returned 503 — Waffle will retry          |
  | `{:error, {:http_error, reason}}`      | Non-retryable error; `reason` is the HTTP status integer for unexpected status codes, or an error term for connection/protocol errors |
  """

  @type body :: binary()
  @type filename :: String.t()
  @type option ::
          {:recv_timeout, non_neg_integer()}
          | {:connect_timeout, non_neg_integer()}
          | {:max_body_length, non_neg_integer() | :infinity}
          | {:follow_redirect, boolean()}

  @callback get(url :: String.t(), headers :: list(), options :: [option()]) ::
              {:ok, body()}
              | {:ok, body(), filename()}
              | {:error, :timeout | :recv_timeout | :service_unavailable | {:http_error, any()}}
end
