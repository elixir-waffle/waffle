defmodule Waffle.Definition do
  defmacro __using__(_options) do
    quote do
      use Waffle.Definition.Versioning
      use Waffle.Definition.Storage

      use Waffle.Actions.Store
      use Waffle.Actions.Delete
      use Waffle.Actions.Url
    end
  end
end
