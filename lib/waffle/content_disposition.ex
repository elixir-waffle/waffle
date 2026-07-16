defmodule Waffle.ContentDisposition do
  @moduledoc false

  @extended_value ~r/\A(?:[A-Za-z0-9!#$&+\-.^_`|~]|%[0-9A-Fa-f]{2})*\z/
  @unsafe_filename ~r/[\x{0000}-\x{001F}\x{007F}-\x{009F}\/\\]/u

  # Preserve Hackney's recovery behavior for non-ASCII bytes in unquoted tokens.
  defguardp token_byte?(byte)
            when byte >= 33 and byte != 127 and
                   byte not in ~c"()<>@,;:\\\"/[]?={} \t"

  defguardp quoted_byte?(byte)
            when byte == ?\t or (byte >= 32 and byte != 127)

  @spec filename(term()) :: binary() | nil
  def filename(value) when is_binary(value) do
    case parse(value) do
      {:ok, parameters} -> select_filename(parameters)
      _ -> nil
    end
  end

  def filename(_value), do: nil

  defp parse(value) do
    case value |> skip_ows() |> token() do
      {:ok, rest, disposition} when disposition != "" -> parameters(rest, %{})
      _ -> :error
    end
  end

  defp parameters(value, acc) do
    case skip_ows(value) do
      "" -> {:ok, acc}
      <<";", rest::binary>> -> parameter_or_end(skip_ows(rest), acc)
      _ -> :error
    end
  end

  defp parameter_or_end("", acc), do: {:ok, acc}
  defp parameter_or_end(value, acc), do: parameter(value, acc)

  defp parameter(data, acc) do
    with {:ok, rest, name} when name != "" <- token(data),
         <<"=", rest::binary>> <- skip_ows(rest),
         {:ok, rest, parameter} <- rest |> skip_ows() |> word(),
         name = String.downcase(name, :ascii),
         false <- Map.has_key?(acc, name) do
      parameters(rest, Map.put(acc, name, parameter))
    else
      _ -> :error
    end
  end

  defp word(<<"\"", _rest::binary>> = value) do
    with {:ok, rest, word} <- quoted_string(value), do: {:ok, rest, {:quoted, word}}
  end

  defp word(value) do
    case token(value) do
      {:ok, _rest, ""} -> :error
      {:ok, rest, word} -> {:ok, rest, {:token, word}}
    end
  end

  defp quoted_string(<<"\"", rest::binary>>), do: quoted_string(rest, "")

  defp quoted_string(<<"\"", rest::binary>>, acc), do: {:ok, rest, acc}

  defp quoted_string(<<"\\", character, rest::binary>>, acc)
       when quoted_byte?(character) do
    quoted_string(rest, <<acc::binary, character>>)
  end

  defp quoted_string(<<character, rest::binary>>, acc)
       when quoted_byte?(character) do
    quoted_string(rest, <<acc::binary, character>>)
  end

  defp quoted_string(_value, _acc), do: :error

  defp token(value), do: token(value, "")

  defp token(<<character, rest::binary>>, acc) when token_byte?(character) do
    token(rest, <<acc::binary, character>>)
  end

  defp token(rest, acc), do: {:ok, rest, acc}

  defp skip_ows(<<character, rest::binary>>) when character in [?\s, ?\t] do
    skip_ows(rest)
  end

  defp skip_ows(value), do: value

  defp select_filename(parameters) do
    [
      decode_extended_filename(parameters["filename*"]),
      parameter_value(parameters["filename"])
    ]
    |> Enum.find_value(&accept_filename/1)
  end

  defp parameter_value({_type, value}), do: value
  defp parameter_value(_parameter), do: nil

  defp decode_extended_filename({:token, value}) do
    with [charset, _language, encoded_filename] <- String.split(value, "'", parts: 3),
         true <- Regex.match?(@extended_value, encoded_filename) do
      decode_charset(String.downcase(charset, :ascii), URI.decode(encoded_filename))
    else
      _ -> nil
    end
  end

  defp decode_extended_filename(_parameter), do: nil

  defp decode_charset("utf-8", value), do: if(String.valid?(value), do: value)

  defp decode_charset("iso-8859-1", value),
    do: :unicode.characters_to_binary(value, :latin1, :utf8)

  defp decode_charset(_charset, _value), do: nil

  defp accept_filename(value) when is_binary(value) and value != "",
    do: if(safe_filename?(value), do: value)

  defp accept_filename(_value), do: nil

  defp safe_filename?(value) do
    if String.valid?(value), do: not (value =~ @unsafe_filename), else: safe_raw_filename?(value)
  end

  defp safe_raw_filename?(<<>>), do: true

  defp safe_raw_filename?(<<byte, rest::binary>>)
       when byte >= 32 and (byte < 127 or byte > 159) and byte not in [?/, ?\\] do
    safe_raw_filename?(rest)
  end

  defp safe_raw_filename?(_value), do: false
end
