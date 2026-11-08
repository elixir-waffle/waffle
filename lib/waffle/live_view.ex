defmodule Waffle.LiveView do
  @moduledoc """
  Provides helpers for Phoenix LiveView file upload handling.
  """

  defmodule Error do
    defstruct [:code, :message]

    @type t :: %__MODULE__{
            code:
              :invalid_filename
              | :empty_filename
              | :filename_too_long
              | :invalid_filename_characters,
            message: String.t()
          }
  end

  @typep live_view_file :: %{required(:path) => String.t(), optional(any()) => any()}
  @typep live_view_upload_entry :: %{
           required(:client_name) => String.t(),
           optional(any()) => any()
         }
  @typep link_mode :: :hard_link | :copy

  @doc ~S"""
  Converts LiveView Upload into a `%Waffle.File{}`.

  ## Options

    * `:hard_link` (default) - creates a hard link under a new tmp path to skip
      on unnecessary filesystem IO
    * `:copy` - copies file to a new location instead of creating a hard link

  ## Examples

      user_params =
        socket
        |> consume_uploaded_entries(:avatar, &Waffle.LiveView.consume_entry/2)
        |> then(fn
          [] -> user_params
          [file | _] -> Map.put(user_params, "avatar", file)
        end)

      updated_user =
        socket.assigns.user
        |> Accounts.User.changeset(user_params)
        |> MyApp.Repo.update()

  to use `:copy` mode

      consume_uploaded_entries(
        socket,
        :avatar,
        &Waffle.LiveView.consume_entry(&1, &2, :copy)
      )
  """
  @spec consume_entry(live_view_file(), live_view_upload_entry(), link_mode()) ::
          {:ok, Waffle.File.t()}
  def consume_entry(file, entry, mode \\ :hard_link) do
    file_name =
      case normalize_client_name(entry.client_name) do
        {:ok, file_name} ->
          file_name

        {:error, %Error{message: message}} ->
          raise ArgumentError, """
          Cannot consume upload: #{message}

          Configure `validator: &Waffle.LiveView.validate/1` in your
          `allow_upload/3` options to reject invalid filenames before consumption.
          """
      end

    path = Waffle.File.generate_temporary_path()

    case mode do
      :hard_link -> File.ln!(file.path, path)
      :copy -> File.cp!(file.path, path)
    end

    {:ok,
     %Waffle.File{
       path: path,
       file_name: file_name,
       is_tempfile?: true
     }}
  end

  @doc ~S"""
  Validates a LiveView upload entry's filename before consumption.

  Configure it as the `:validator` callback in `allow_upload/3`:

      allow_upload(socket, :avatar,
        accept: ~w(.jpg .jpeg .png),
        validator: &Waffle.LiveView.validate/1
      )

  Display Waffle validation errors using `Phoenix.Component.upload_errors/2`:

  ```heex
  <div :for={entry <- @uploads.avatar.entries}>
    <p :for={%Waffle.LiveView.Error{} = error <- upload_errors(@uploads.avatar, entry)}>
      {error.message}
    </p>
  </div>
  ```

  Built-in LiveView upload errors need separate handling.
  """
  @spec validate(live_view_upload_entry()) :: :ok | {:error, Error.t()}
  def validate(entry) do
    case normalize_client_name(entry.client_name) do
      {:ok, _file_name} -> :ok
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp normalize_client_name(client_name) do
    file_name =
      client_name
      |> String.replace("\\", "/")
      |> Path.basename()

    cond do
      file_name in [".", ".."] ->
        {:error, %Error{code: :invalid_filename, message: "filename cannot be '.' or '..'"}}

      String.trim(file_name) == "" ->
        {:error, %Error{code: :empty_filename, message: "filename cannot be empty"}}

      byte_size(file_name) > 240 ->
        {:error, %Error{code: :filename_too_long, message: "filename must not exceed 240 bytes"}}

      Regex.match?(~r/[\p{Cc}\p{Cf}]/u, file_name) ->
        {:error,
         %Error{
           code: :invalid_filename_characters,
           message: "filename contains unsupported characters"
         }}

      true ->
        {:ok, file_name}
    end
  end
end
