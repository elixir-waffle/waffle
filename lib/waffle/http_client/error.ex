defmodule Waffle.HTTPClient.Error do
  @moduledoc false

  defstruct [:request, :error_context, :error]
end
