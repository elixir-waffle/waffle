defmodule Waffle.HTTPClient.Req do
  @behaviour Waffle.HTTPClient

  # see [related discussion](https://github.com/wojtekmach/req/issues/355) for max body length

  alias Waffle.HTTPClient.{Error, Response, ResponseBodyLimitError}

  @impl true
  def get(url, headers, options) do
    max_body_length_bytes = Keyword.fetch!(options, :max_body_length_bytes)
    receive_timeout_ms = Keyword.fetch!(options, :receive_timeout_ms)
    connect_timeout_ms = Keyword.fetch!(options, :connect_timeout_ms)
    max_redirects = Keyword.fetch!(options, :max_redirects)

    config_request_options =
      Application.get_env(:waffle, __MODULE__, []) |> Keyword.get(:request_options, [])

    request =
      [
        url: url,
        method: :get,
        headers: headers,
        receive_timeout: receive_timeout_ms,
        connect_options: [timeout: connect_timeout_ms],
        retry: false,
        decode_body: false
      ]
      |> maybe_with_redirects(max_redirects)
      |> maybe_with_max_body_length(max_body_length_bytes)
      |> Keyword.merge(config_request_options)
      |> Req.new()

    case Req.request(request) do
      {:ok, response = %Req.Response{status: 200}} ->
        filename =
          response
          |> Req.Response.get_header("content-disposition")
          |> List.first()
          |> Waffle.ContentDisposition.filename()

        {:ok,
         %Response{
           body: response.body,
           filename: filename
         }}

      {:ok, response = %Req.Response{status: status}} ->
        {:error,
         %Error{request: request, error_context: response, error: {:unexpected_status, status}}}

      {:error, error = %Req.TransportError{reason: :timeout}} ->
        {:error, %Error{request: request, error_context: error, error: :timeout}}

      {:error, error = %ResponseBodyLimitError{}} ->
        {:error,
         %Error{
           request: request,
           error_context: error,
           error: :response_body_limit_exceeded
         }}

      {:error, exception} ->
        {:error, %Error{request: request, error_context: exception, error: :http_client}}
    end
  end

  defp maybe_with_max_body_length(request, nil), do: request

  defp maybe_with_max_body_length(request, max_body_length_bytes) do
    Keyword.put(request, :into, fn {:data, data}, {req, resp} ->
      content_length_within_limit? =
        with [content_length_header] <- Req.Response.get_header(resp, "content-length"),
             {content_length_bytes, ""} <- Integer.parse(content_length_header) do
          content_length_bytes <= max_body_length_bytes
        else
          _ -> true
        end

      req =
        Req.Request.update_private(
          req,
          :response_body_size_bytes,
          byte_size(data),
          &(&1 + byte_size(data))
        )

      body_within_limit? =
        Req.Request.get_private(req, :response_body_size_bytes) <= max_body_length_bytes

      if content_length_within_limit? && body_within_limit? do
        resp = update_in(resp.body, &(&1 <> data))

        {:cont, {req, resp}}
      else
        {:halt, {req, ResponseBodyLimitError.exception(limit_bytes: max_body_length_bytes)}}
      end
    end)
  end

  defp maybe_with_redirects(options, nil) do
    options ++ [redirect: false]
  end

  defp maybe_with_redirects(options, max_redirects) do
    options ++ [redirect: true, redirect_trusted: false, max_redirects: max_redirects]
  end
end
