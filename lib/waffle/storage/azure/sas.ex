defmodule Waffle.Storage.Azure.SAS do
  @moduledoc """
  Handles generation of Shared Access Signature (SAS) tokens for Azure Blob Storage.
  """

  @doc """
  Generates a SAS token for accessing a blob.
  """
  def generate_sas_token(storage_account, container, blob_name, access_key, expiry_in_seconds) do
    now = DateTime.utc_now()
    expiry = DateTime.add(now, expiry_in_seconds, :second)

    permissions = "r"  # Read permission
    resource_type = "b"  # Blob resource type
    canonicalized_resource = "/blob/#{storage_account}/#{container}/#{blob_name}"

    # String to sign for Azure Blob Storage SAS version 2020-12-06
    string_to_sign = [
      permissions,  # sp (signedPermissions)
      iso8601_z(now),  # st (signedStart)
      iso8601_z(expiry),  # se (signedExpiry)
      canonicalized_resource,  # canonicalized resource
      "",  # signedIdentifier
      "",  # signedIP
      "https",  # signedProtocol
      "2020-12-06",  # sv (signedVersion)
      resource_type,  # sr (signedResource)
      "",  # signedSnapshotTime
      "",  # signedEncryptionScope
      "",  # rscc
      "",  # rscd
      "",  # rsce
      "",  # rscl
      ""   # rsct
    ]
    |> Enum.join("\n")

    decoded_key = :base64.decode(access_key)
    signature = :crypto.mac(:hmac, :sha256, decoded_key, string_to_sign) |> Base.encode64()

    # Build query parameters
    query_params = %{
      "sv" => "2020-12-06",  # version
      "st" => iso8601_z(now),  # start time
      "se" => iso8601_z(expiry),  # expiry
      "sr" => resource_type,  # resource type
      "sp" => permissions,  # permissions
      "spr" => "https",  # signed protocol
      "sig" => signature  # signature
    }

    URI.encode_query(query_params)
  end

  @doc """
  Generates a complete SAS URL for a blob.
  """
  def generate_sas_url(storage_account, container, blob_name, access_key, expiry_in_seconds) do
    try do
      sas_token = generate_sas_token(storage_account, container, blob_name, access_key, expiry_in_seconds)
      url = "https://#{storage_account}.blob.core.windows.net/#{container}/#{blob_name}?#{sas_token}"
      {:ok, url}
    rescue
      error ->
        {:error, "Failed to generate SAS URL: #{inspect(error)}"}
    end
  end

  # Helper function to format datetime in UTC with Z suffix (Azure-compatible)
  defp iso8601_z(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%dT%H:%M:%SZ")
  end
end
