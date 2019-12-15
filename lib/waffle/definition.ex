defmodule Waffle.Definition do
  @moduledoc ~S"""
  Defines uploader to manage files.

      defmodule Avatar do
        use Waffle.Definition
      end

  Consists of several components to manage different parts of file
  managing process.

    * `Waffle.Definition.Versioning`

    * `Waffle.Definition.Storage`

    * `Waffle.Actions.Store`

    * `Waffle.Actions.Delete`

    * `Waffle.Actions.Url`

  """

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
