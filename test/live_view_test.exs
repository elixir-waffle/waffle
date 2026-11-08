defmodule WaffleTest.LiveView do
  use ExUnit.Case, async: false

  describe "validate/1" do
    test "with empty name" do
      for client_name <- ["", "   "] do
        assert {:error, %Waffle.LiveView.Error{code: :empty_filename}} =
                 Waffle.LiveView.validate(%{client_name: client_name})
      end
    end

    test "with dot name" do
      for client_name <- [".", ".."] do
        assert {:error, %Waffle.LiveView.Error{code: :invalid_filename}} =
                 Waffle.LiveView.validate(%{client_name: client_name})
      end
    end
  end

  describe "consume_entry/3" do
    setup do
      source_path = Waffle.File.generate_temporary_path()
      File.write!(source_path, "uploaded content")
      on_exit(fn -> File.rm(source_path) end)

      {:ok, source_path: source_path}
    end

    test "with hard_link", %{source_path: source_path} do
      assert {:ok, %Waffle.File{} = file} =
               Waffle.LiveView.consume_entry(
                 %{path: source_path},
                 %{client_name: "C:\\fakepath\\avatar.png"}
               )

      on_exit(fn -> File.rm(file.path) end)

      assert file.file_name == "avatar.png"
      assert file.is_tempfile?
      assert file.path != source_path
      assert File.stat!(file.path).inode == File.stat!(source_path).inode
    end

    test "with copy", %{source_path: source_path} do
      assert {:ok, %Waffle.File{} = file} =
               Waffle.LiveView.consume_entry(
                 %{path: source_path},
                 %{client_name: "uploads/avatar.png"},
                 :copy
               )

      on_exit(fn -> File.rm(file.path) end)

      assert file.file_name == "avatar.png"
      assert file.is_tempfile?
      assert File.read!(file.path) == "uploaded content"

      File.write!(source_path, "content")

      assert File.read!(file.path) == "uploaded content"
    end
  end
end
