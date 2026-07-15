defmodule Waffle.HTTPClient.ContentDisposition do
  @moduledoc """
  Parses filenames out of `Content-Disposition` header values.

  Supports both the RFC 5987 extended notation (`filename*=...`), which
  takes priority per RFC 6266 when both are present, and the plain
  `filename=` parameter (quoted or unquoted).
  """

  @doc """
  Extracts the filename from a `Content-Disposition` header value.

  Returns `nil` if no filename parameter is present.

  ## Examples

      iex> Waffle.HTTPClient.ContentDisposition.filename(~s(attachment; filename="photo.jpg"))
      "photo.jpg"

      iex> Waffle.HTTPClient.ContentDisposition.filename("attachment; filename*=UTF-8''my%20photo.jpg")
      "my photo.jpg"

      iex> Waffle.HTTPClient.ContentDisposition.filename("inline")
      nil

  """
  @spec filename(String.t()) :: String.t() | nil
  def filename(value) when is_binary(value) do
    params = parse_params(value)

    case Map.fetch(params, "filename*") do
      {:ok, extended_value} ->
        decode_extended_value(extended_value)

      :error ->
        Map.get(params, "filename")
    end
  end

  # Splits "type; key=value; key2="value 2"" into a map of downcased
  # parameter names to their unquoted/unescaped values. The leading
  # disposition-type token (e.g. "attachment"/"inline") is discarded.
  defp parse_params(value) do
    value
    |> split_semicolons()
    |> Enum.drop(1)
    |> Enum.reduce(%{}, fn part, acc ->
      case parse_param(String.trim(part)) do
        {key, val} -> Map.put_new(acc, key, val)
        :error -> acc
      end
    end)
  end

  # Splits on `;`, while treating the contents of a double-quoted string as
  # opaque so that a `;` inside a quoted filename doesn't split it.
  defp split_semicolons(value), do: split_semicolons(value, <<>>, [], false)

  defp split_semicolons(<<?\\, char, rest::binary>>, acc, parts, true) do
    split_semicolons(rest, <<acc::binary, ?\\, char>>, parts, true)
  end

  defp split_semicolons(<<?", rest::binary>>, acc, parts, quoted?) do
    split_semicolons(rest, <<acc::binary, ?">>, parts, not quoted?)
  end

  defp split_semicolons(<<?;, rest::binary>>, acc, parts, false) do
    split_semicolons(rest, <<>>, [acc | parts], false)
  end

  defp split_semicolons(<<char, rest::binary>>, acc, parts, quoted?) do
    split_semicolons(rest, <<acc::binary, char>>, parts, quoted?)
  end

  defp split_semicolons(<<>>, acc, parts, _quoted?) do
    Enum.reverse([acc | parts])
  end

  # Parses a single "key=value" parameter, downcasing the key and
  # unquoting/unescaping the value if it's a quoted string. Returns
  # `:error` for anything that isn't a well-formed, non-empty parameter.
  defp parse_param(param) do
    with [key, value] <- :binary.split(param, "="),
         value <- value |> String.trim() |> unquote_value(),
         false <- value == "" do
      {key |> String.trim() |> String.downcase(), value}
    else
      _ -> :error
    end
  end

  defp unquote_value(<<?", rest::binary>>), do: parse_quoted(rest, <<>>)
  defp unquote_value(value), do: unquoted_token(value, <<>>)

  defp parse_quoted(<<?\\, char, rest::binary>>, acc), do: parse_quoted(rest, <<acc::binary, char>>)
  defp parse_quoted(<<?", _rest::binary>>, acc), do: acc
  defp parse_quoted(<<char, rest::binary>>, acc), do: parse_quoted(rest, <<acc::binary, char>>)
  defp parse_quoted(<<>>, acc), do: acc

  defp unquoted_token(<<>>, acc), do: acc
  defp unquoted_token(<<char, _rest::binary>>, acc) when char in [?\s, ?\t], do: acc
  defp unquoted_token(<<char, rest::binary>>, acc), do: unquoted_token(rest, <<acc::binary, char>>)

  # RFC 5987: charset'language'percent-encoded-value,
  # e.g. UTF-8''my%20photo.jpg or UTF-8'en'my%20photo.jpg
  defp decode_extended_value(value) do
    case String.split(value, "'", parts: 3) do
      [_charset, _language, encoded] -> safe_uri_decode(encoded)
      _ -> safe_uri_decode(value)
    end
  end

  # A malformed percent-encoding (e.g. a trailing "%" or "%zz") makes
  # `URI.decode/1` raise. Fall back to the raw (un-decoded) value rather than
  # crashing the caller over a malformed header from a remote server.
  defp safe_uri_decode(value) do
    URI.decode(value)
  rescue
    ArgumentError -> value
  end
end
