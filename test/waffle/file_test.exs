defmodule WaffleTest.FileTest do
  use ExUnit.Case, async: true

  alias Waffle.File

  describe "parse_content_disposition_filename/1" do
    test "quoted filename" do
      assert File.parse_content_disposition_filename(~s(attachment; filename="image.png")) ==
               "image.png"
    end

    test "unquoted filename" do
      assert File.parse_content_disposition_filename("attachment; filename=image.png") ==
               "image.png"
    end

    test "quoted filename with spaces" do
      assert File.parse_content_disposition_filename(
               ~s(attachment; filename="image three.png")
             ) == "image three.png"
    end

    test "inline disposition with no filename returns nil" do
      assert File.parse_content_disposition_filename("inline") == nil
    end

    test "attachment with no filename returns nil" do
      assert File.parse_content_disposition_filename("attachment") == nil
    end

    test "empty quoted filename returns nil" do
      assert File.parse_content_disposition_filename(~s(attachment; filename="")) == nil
    end

    test "filename with multiple parameters" do
      assert File.parse_content_disposition_filename(
               ~s(attachment; size=1234; filename="report.pdf"; charset=utf-8)
             ) == "report.pdf"
    end

    test "RFC 5987 extended filename* parameter without plain filename returns nil" do
      assert File.parse_content_disposition_filename(
               "attachment; filename*=UTF-8''my%20file.txt"
             ) == nil
    end
  end
end
