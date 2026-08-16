defmodule Waffle.HTTPClient.Error do
  defstruct [:request, :error_context, :error]
end
