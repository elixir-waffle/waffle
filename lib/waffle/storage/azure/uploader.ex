defmodule Waffle.Storage.Azure.Uploader do
  @moduledoc """
  Handles file uploads to Azure Blob Storage using Shared Key authentication.
  """

  require Logger

  @doc """
  Uploads a file to Azure Blob Storage.
  """
  def upload_file(file_binary, container, blob_name, headers \\ []) do
    config = azure_config()

    storage_account = config.storage_account
    access_key = config.access_key

    url = "https://#{storage_account}.blob.core.windows.net/#{container}/#{blob_name}"

    datetime = generate_utc_datetime()
    content_length = byte_size(file_binary)
    content_type = Keyword.get(headers, :content_type, "application/octet-stream")

    auth_headers = [
      {"x-ms-date", datetime},
      {"x-ms-version", "2020-08-04"},
      {"x-ms-blob-type", "BlockBlob"},
      {"Content-Length", "#{content_length}"},
      {"Content-Type", content_type}
    ]

    # Add custom headers
    custom_headers =
      headers
      |> Keyword.drop([:content_type])
      |> Enum.map(fn {key, value} -> {to_string(key), to_string(value)} end)

    all_headers = auth_headers ++ custom_headers ++ [
      {"Authorization", authorization("PUT", datetime, content_length, blob_name, storage_account, container, access_key, content_type)}
    ]

    case Req.put(url, headers: all_headers, body: file_binary) do
      {:ok, %Req.Response{status: 201}} -> {:ok, blob_name}
      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("[AzureUploader] Upload failed with status #{status}: #{inspect(body)}")
        {:error, "Upload failed with status #{status}"}
      {:error, reason} ->
        Logger.error("[AzureUploader] Upload error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Deletes a blob from Azure Blob Storage.
  """
  def delete_blob(container, blob_name) do
    config = azure_config()

    storage_account = config.storage_account
    access_key = config.access_key

    url = "https://#{storage_account}.blob.core.windows.net/#{container}/#{blob_name}"

    datetime = generate_utc_datetime()

    headers = [
      {"x-ms-date", datetime},
      {"x-ms-version", "2020-08-04"},
      {"Authorization", authorization("DELETE", datetime, 0, blob_name, storage_account, container, access_key, "")}
    ]

    case Req.delete(url, headers: headers) do
      {:ok, %Req.Response{status: 202}} -> {:ok, :deleted}
      {:ok, %Req.Response{status: 404}} -> {:ok, :not_found}
      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("[AzureUploader] Delete failed with status #{status}: #{inspect(body)}")
        {:error, "Delete failed with status #{status}"}
      {:error, reason} ->
        Logger.error("[AzureUploader] Delete error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp azure_config do
    %{
      storage_account: Application.fetch_env!(:waffle, :storage_account),
      access_key: Application.fetch_env!(:waffle, :access_key)
    }
  end

  defp generate_utc_datetime do
    Timex.now("Etc/UTC")
    |> Timex.format!("{WDshort}, {0D} {Mshort} {YYYY} {h24}:{m}:{s} GMT")
  end

  defp authorization(method, date, content_length, blob_name, storage_account, container, access_key, content_type) do
    canonicalized_resource = "/#{storage_account}/#{container}/#{blob_name}"

    string_to_sign = [
      method,
      "",  # Content-Encoding
      "",  # Content-Language
      "#{content_length}",  # Content-Length
      "",  # Content-MD5
      content_type,  # Content-Type
      "",  # Date
      "",  # If-Modified-Since
      "",  # If-Match
      "",  # If-None-Match
      "",  # If-Unmodified-Since
      "",  # Range
      "x-ms-blob-type:BlockBlob",
      "x-ms-date:#{date}",
      "x-ms-version:2020-08-04",
      canonicalized_resource
    ]
    |> Enum.join("\n")

    decoded_key = :base64.decode(access_key)
    signature = :crypto.mac(:hmac, :sha256, decoded_key, string_to_sign) |> Base.encode64()
    "SharedKey #{storage_account}:#{signature}"
  end
end
