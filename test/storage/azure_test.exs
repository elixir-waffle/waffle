defmodule Waffle.Storage.AzureTest do
  use ExUnit.Case, async: true

  alias Waffle.Storage.Azure

  describe "SAS token generation" do
    test "generates valid SAS token" do
      storage_account = "testaccount"
      container = "testcontainer"
      blob_name = "test/blob.jpg"
      access_key = "dGVzdGtleQ=="  # "testkey" in base64
      expiry_in_seconds = 3600

      sas_token = Azure.SAS.generate_sas_token(storage_account, container, blob_name, access_key, expiry_in_seconds)

      # Check that the SAS token contains required parameters
      assert String.contains?(sas_token, "sv=2020-12-06")
      assert String.contains?(sas_token, "sp=r")
      assert String.contains?(sas_token, "sr=b")
      assert String.contains?(sas_token, "spr=https")
      assert String.contains?(sas_token, "sig=")
    end
  end

  describe "SAS URL generation" do
    test "generates complete SAS URL" do
      storage_account = "testaccount"
      container = "testcontainer"
      blob_name = "test/blob.jpg"
      access_key = "dGVzdGtleQ=="  # "testkey" in base64
      expiry_in_seconds = 3600

      {:ok, url} = Azure.SAS.generate_sas_url(storage_account, container, blob_name, access_key, expiry_in_seconds)

      assert String.starts_with?(url, "https://testaccount.blob.core.windows.net/testcontainer/test/blob.jpg")
      assert String.contains?(url, "?")
    end

    test "handles errors gracefully" do
      # Test with invalid access key
      result = Azure.SAS.generate_sas_url("account", "container", "blob", "invalid_key", 3600)

      assert {:error, _} = result
    end
  end
end
