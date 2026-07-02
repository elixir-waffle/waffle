defmodule WaffleTest.HTTPClient do
  use ExUnit.Case, async: true

  describe "parse_content_disposition/1" do
    test "parses a quoted filename" do
      result = Waffle.HTTPClient.parse_content_disposition(~s(attachment; filename="photo.jpg"))
      assert result == "photo.jpg"
    end

    test "parses an unquoted filename" do
      result = Waffle.HTTPClient.parse_content_disposition("attachment; filename=photo.jpg")
      assert result == "photo.jpg"
    end

    test "parses a filename when multiple parameters are present" do
      result =
        Waffle.HTTPClient.parse_content_disposition(
          ~s(attachment; filename="report.pdf"; size=1024)
        )

      assert result == "report.pdf"
    end

    test "returns nil when no filename parameter is present" do
      assert Waffle.HTTPClient.parse_content_disposition("attachment") == nil
    end

    test "returns nil for inline disposition without filename" do
      assert Waffle.HTTPClient.parse_content_disposition("inline") == nil
    end
  end
end
