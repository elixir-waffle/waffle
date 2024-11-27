defmodule Waffle.StorageBehavior do
  @moduledoc """
  Defines the behavior for file storage.

  ## Callbacks

  - `put/3`: Saves a file and returns the file name or an error.
  - `url/3`: Generates a URL for accessing a file.
  - `delete/3`: Deletes a file and returns the result of the operation.
  """

  @callback put(definition :: atom, version :: atom, file_and_scope :: {Waffle.File.t(), any}) ::
              {:ok, file_name :: String.t()} | {:error, reason :: any}

  @callback url(definition :: atom, version :: atom, file_and_scope :: {Waffle.File.t(), any}) ::
              String.t()

  @callback delete(definition :: atom, version :: atom, file_and_scope :: {Waffle.File.t(), any}) ::
              atom
end
