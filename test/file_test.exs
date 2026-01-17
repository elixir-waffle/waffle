defmodule WaffleTest.File do
  use ExUnit.Case, async: false

  @custom_tmp_dir System.tmp_dir() <> "/waffle_test_custom"

  describe "generate_temporary_path/1" do
    test "uses configured tmp_dir" do
      File.mkdir_p!(@custom_tmp_dir)
      Application.put_env(:waffle, :tmp_dir, @custom_tmp_dir)

      assert Waffle.File.generate_temporary_path() |> String.starts_with?(@custom_tmp_dir)
      on_exit fn ->
        Application.delete_env(:waffle, :tmp_dir)
        File.rm_rf!(@custom_tmp_dir)
      end
    end

    test "uses system tmp_dir" do
      assert Waffle.File.generate_temporary_path() |> String.starts_with?(System.tmp_dir())
    end
  end
end
