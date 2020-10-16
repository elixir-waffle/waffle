defmodule Waffle.Definition.Validation do
  @moduledoc """
  File validation by MIME types

      Validation.validate("mix.exs", ["text/x-ruby"])
      => :ok

  Validation process:

  1. We get content type of a file by the `file` utility

  2. We check that `MIME` library recognizes such content type

  3. Next, we check that returnted content type matches expected
     extensions list for that particular content type

  4. Finally, we check if this content type is allowed

  """

  def validate(filepath, :all), do: :ok

  def validate(filepath, valid_content_types) do
    with {:ok, content_type} <- content_type(filepath),
         :ok <- mime_is_valid(content_type),
         :ok <- extension_matches_mime(filepath, content_type),
         :ok <- mime_is_allowed(valid_content_types, content_type) do
      :ok
    else
      {:error, message} -> {:error, message}
    end
  end

  def mime_is_valid(content_type) do
    if MIME.valid?(content_type) do
      :ok
    else
      {:error, ["content type is invalid"]}
    end
  end

  def extension_matches_mime(filepath, content_type) do
    # TODO add custom extensions
    if MIME.extensions(content_type)
       |> Enum.member?(filepath |> Path.extname() |> String.downcase()) do
      :ok
    else
      {:error, ["content type and extension doesn't match"]}
    end
  end

  def mime_is_allowed(valid_content_types, content_type) do
    if Enum.member?(valid_content_types, content_type) do
      :ok
    else
      {:error, ["invalid file format"]}
    end
  end

  def content_type(filepath) do
    with true <- File.exists?(filepath),
         {file_utility_output, 0} <- System.cmd("file", ["--mime", "--brief", filepath]) do
      content_type =
        Regex.named_captures(
          ~r/^(?<content_type>.+);/,
          file_utility_output
        )["content_type"]

      {:ok, content_type}
    else
      {error, 1} ->
        {:error, error}

      false ->
        "inode/x-empty"
    end
  end
end
