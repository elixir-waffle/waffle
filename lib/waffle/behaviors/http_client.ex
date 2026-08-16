defmodule Waffle.HTTPClient do
  @moduledoc false

  @type url :: String.t()
  @type header :: {String.t(), String.t()}
  @type headers :: [header()]
  @type body :: binary()
  @type filename :: String.t()
  @type status :: 100..599
  @type option ::
          {:max_redirects, non_neg_integer() | nil}
          | {:max_retries, non_neg_integer()}
          | {:receive_timeout_ms, non_neg_integer()}
          | {:connect_timeout_ms, non_neg_integer()}
          | {:max_body_length_bytes, non_neg_integer() | nil}
          | {:backoff_factor_ms, non_neg_integer()}
          | {:backoff_max_ms, non_neg_integer()}
  @type options :: [option()]
  @type response :: %Waffle.HTTPClient.Response{
          body: body(),
          filename: filename() | nil
        }
  @type error ::
          :timeout
          | {:unexpected_status, status()}
          | :response_body_limit_exceeded
          | :http_client
  @type error_response :: %Waffle.HTTPClient.Error{
          request: term(),
          error_context: term(),
          error: error()
        }

  @callback get(url(), headers(), options()) ::
              {:ok, response()} | {:error, error_response()}
end
