defmodule Waffle.Storage.AzureTest do
  use ExUnit.Case, async: true

  alias Waffle.Storage.Azure

  describe "build_blob_name/3" do
    test "builds correct blob name with storage directory" do
      definition = %{
        storage_dir: fn :thumb, _ -> "uploads/avatars" end
      }

      file = %Waffle.File{file_name: "test.jpg"}
      scope = %{id: 123}

      blob_name = Azure.build_blob_name(definition, :thumb, {file, scope})

      assert blob_name == "uploads/avatars/test.jpg"
    end

    test "builds correct blob name without storage directory" do
      definition = %{
        storage_dir: fn :thumb, _ -> "" end
      }

      file = %Waffle.File{file_name: "test.jpg"}
      scope = %{id: 123}

      blob_name = Azure.build_blob_name(definition, :thumb, {file, scope})

      assert blob_name == "test.jpg"
    end
  end

  describe "parse_config_value/1" do
    test "parses system environment variable" do
      System.put_env("TEST_VAR", "test_value")

      result = Azure.parse_config_value({:system, "TEST_VAR"})

      assert result == "test_value"

      System.delete_env("TEST_VAR")
    end

    test "returns value directly when not system tuple" do
      result = Azure.parse_config_value("direct_value")

      assert result == "direct_value"
    end
  end
end
