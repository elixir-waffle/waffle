defmodule Waffle.HTTPClient.ResponseBodyLimitError do
  defexception [:limit_bytes]

  @impl Exception
  def message(%__MODULE__{limit_bytes: limit_bytes}) do
    "response body is larger than #{limit_bytes} bytes"
  end
end
