defmodule WaffleTest.HTTPClient.ContentDisposition do
  use ExUnit.Case, async: true
  doctest Waffle.HTTPClient.ContentDisposition

  alias Waffle.HTTPClient.ContentDisposition

  describe "filename/1" do
    test "returns nil when there is no filename parameter" do
      assert ContentDisposition.filename("inline") == nil
    end

    test "returns nil for an attachment with no filename parameter" do
      assert ContentDisposition.filename("attachment") == nil
    end

    test "parses a quoted filename" do
      assert ContentDisposition.filename(~s(attachment; filename="photo.jpg")) == "photo.jpg"
    end

    test "parses an unquoted filename" do
      assert ContentDisposition.filename("attachment; filename=photo.jpg") == "photo.jpg"
    end

    test "parses an unquoted filename terminated by a semicolon" do
      assert ContentDisposition.filename("attachment; filename=photo.jpg; size=1234") ==
               "photo.jpg"
    end

    test "decodes an RFC 5987 filename*= value" do
      assert ContentDisposition.filename("attachment; filename*=UTF-8''my%20photo.jpg") ==
               "my photo.jpg"
    end

    test "decodes an RFC 5987 filename*= value with a language tag" do
      assert ContentDisposition.filename("attachment; filename*=UTF-8'en'my%20photo.jpg") ==
               "my photo.jpg"
    end

    test "prefers filename*= over filename= when both are present" do
      value = ~s(attachment; filename="fallback.jpg"; filename*=UTF-8''preferred.jpg)
      assert ContentDisposition.filename(value) == "preferred.jpg"
    end

    test "prefers filename*= over filename= regardless of parameter order" do
      value = ~s(attachment; filename*=UTF-8''preferred.jpg; filename="fallback.jpg")
      assert ContentDisposition.filename(value) == "preferred.jpg"
    end

    test "handles filename= with no value gracefully" do
      assert ContentDisposition.filename("attachment; filename=") == nil
    end

    test "is case-insensitive for the filename parameter name" do
      assert ContentDisposition.filename(~s(attachment; FILENAME="photo.jpg")) == "photo.jpg"
    end

    test "unescapes backslash-escaped quotes inside a quoted filename" do
      value = ~S(attachment; filename="my \"quoted\" file.jpg")
      assert ContentDisposition.filename(value) == ~s(my "quoted" file.jpg)
    end

    test "unescapes backslash-escaped backslashes inside a quoted filename" do
      value = ~S(attachment; filename="C:\\Users\\file.jpg")
      assert ContentDisposition.filename(value) == ~S(C:\Users\file.jpg)
    end

    test "does not split on a semicolon inside a quoted filename" do
      value = ~s(attachment; filename="file; with; semicolons.jpg")
      assert ContentDisposition.filename(value) == "file; with; semicolons.jpg"
    end

    test "handles a trailing parameter after a quoted filename" do
      value = ~s(attachment; filename="photo.jpg"; size=1234)
      assert ContentDisposition.filename(value) == "photo.jpg"
    end

    test "ignores whitespace around the equals sign" do
      assert ContentDisposition.filename(~s(attachment; filename = "photo.jpg")) == "photo.jpg"
    end

    test "best-effort parses an unterminated quoted filename (missing closing quote)" do
      assert ContentDisposition.filename(~s(attachment; filename="photo.jpg)) == "photo.jpg"
    end
  end
end
