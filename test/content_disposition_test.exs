defmodule WaffleTest.ContentDisposition do
  use ExUnit.Case, async: true

  alias Waffle.ContentDisposition

  describe "filename/1" do
    test "supports the RFC 6266 section 5 examples" do
      examples = [
        {"Attachment; filename=example.html", "example.html"},
        {~s(INLINE; FILENAME= "an example.html"), "an example.html"},
        {"attachment; filename*= UTF-8''%e2%82%ac%20rates", "€ rates"},
        {~s(attachment; filename="EURO rates"; filename*=utf-8''%e2%82%ac%20rates), "€ rates"}
      ]

      for {header, expected_filename} <- examples do
        assert ContentDisposition.filename(header) == expected_filename
      end
    end

    test "parses quoted and token filenames from any disposition type" do
      assert ContentDisposition.filename(~s(attachment; filename="photo.jpg")) == "photo.jpg"
      assert ContentDisposition.filename("inline; filename=photo.jpg") == "photo.jpg"

      assert ContentDisposition.filename("form-data; name=file; filename=photo.jpg") ==
               "photo.jpg"
    end

    test "preserves Hackney compatibility for unquoted non-ASCII filenames" do
      assert ContentDisposition.filename("attachment; filename=føø.jpg") == "føø.jpg"

      latin1_filename = <<"caf", 0xE9, ".txt">>

      assert ContentDisposition.filename("attachment; filename=" <> latin1_filename) ==
               latin1_filename
    end

    test "handles case-insensitive names and optional whitespace" do
      assert ContentDisposition.filename(~s( ATTACHMENT ; FILENAME = "photo.jpg" )) ==
               "photo.jpg"
    end

    test "finds filename after other parameters" do
      assert ContentDisposition.filename(
               ~s(attachment; creation-date="today"; filename="photo.jpg")
             ) == "photo.jpg"
    end

    test "handles semicolons and escaped characters inside quoted filenames" do
      assert ContentDisposition.filename(~s(attachment; filename="a;b.jpg")) == "a;b.jpg"
      assert ContentDisposition.filename(~s(attachment; filename="a\\\"b.jpg")) == ~s(a"b.jpg)
      assert ContentDisposition.filename(~s(attachment; filename=" photo.jpg ")) == " photo.jpg "
    end

    test "tolerates a trailing semicolon like Hackney" do
      assert ContentDisposition.filename(~s(attachment; filename="photo.jpg";)) == "photo.jpg"

      assert ContentDisposition.filename(~s(attachment; filename="photo.jpg"; \t )) ==
               "photo.jpg"
    end

    test "supports representative Greenbytes quoted filename cases" do
      assert ContentDisposition.filename(~s(inline; filename="foo.html")) == "foo.html"
      assert ContentDisposition.filename(~s(attachment; filename="f\\oo.html")) == "foo.html"

      assert ContentDisposition.filename(~s(attachment; filename="\\\"quoting\\\" tested.html")) ==
               ~s("quoting" tested.html)

      assert ContentDisposition.filename(~s(attachment; filename="foo;bar.html")) ==
               "foo;bar.html"
    end

    test "prefers UTF-8 filename* over filename" do
      assert ContentDisposition.filename(
               ~s(attachment; filename="fallback.jpg"; filename*=UTF-8''f%C3%B8%C3%B8.jpg)
             ) == "føø.jpg"

      assert ContentDisposition.filename(
               ~s(attachment; filename*=utf-8''preferred.jpg; filename="fallback.jpg")
             ) == "preferred.jpg"
    end

    test "decodes spaces and preserves plus signs in filename*" do
      assert ContentDisposition.filename(
               "attachment; filename*=UTF-8''quarterly%20report+notes.pdf"
             ) == "quarterly report+notes.pdf"
    end

    test "decodes characters that must be percent-encoded in filename*" do
      assert ContentDisposition.filename("attachment; filename*=UTF-8''foo%2Abar%27baz.jpg") ==
               "foo*bar'baz.jpg"
    end

    test "supports and ignores a language component in filename*" do
      assert ContentDisposition.filename("attachment; filename*=UTF-8'en'%E2%82%ACrates.pdf") ==
               "€rates.pdf"
    end

    test "supports case-insensitive UTF-8 and ISO-8859-1 charsets" do
      assert ContentDisposition.filename("attachment; filename*=uTf-8''%E2%82%ACrates.pdf") ==
               "€rates.pdf"

      assert ContentDisposition.filename("attachment; filename*=ISO-8859-1''caf%E9.txt") ==
               "café.txt"
    end

    test "falls back to filename when filename* cannot be decoded" do
      for extended_value <- [
            "UTF-8''bad%ZZ.jpg",
            "UTF-8''bad%.jpg",
            "UTF-8''bad%A.jpg",
            "UTF-8''bad%FF.jpg",
            "UTF-16''photo.jpg",
            "UTF-8'photo.jpg",
            "UTF-8''",
            "photo.jpg"
          ] do
        header =
          ~s(attachment; filename="fallback.jpg"; filename*=#{extended_value})

        assert ContentDisposition.filename(header) == "fallback.jpg"
      end
    end

    test "rejects unsafe regular filenames" do
      unsafe_headers = [
        ~s(attachment; filename=""),
        ~s(attachment; filename="../secret.txt"),
        ~s(attachment; filename="..\\\\secret.txt"),
        ~s(attachment; filename="folder/photo.jpg"),
        "attachment; filename=\"photo\u0085.jpg\""
      ]

      for header <- unsafe_headers do
        assert ContentDisposition.filename(header) == nil
      end
    end

    test "falls back to filename when filename* decodes to unsafe characters" do
      for extended_value <- [
            "UTF-8''photo%00.jpg",
            "UTF-8''photo%09.jpg",
            "UTF-8''photo%0D%0A.jpg",
            "UTF-8''photo%1B.jpg",
            "UTF-8''photo%7F.jpg",
            "UTF-8''photo%C2%85.jpg",
            "ISO-8859-1''photo%85.jpg",
            "UTF-8''..%2Fsecret.txt",
            "UTF-8''..%5Csecret.txt"
          ] do
        header =
          ~s(attachment; filename="fallback.jpg"; filename*=#{extended_value})

        assert ContentDisposition.filename(header) == "fallback.jpg"
      end
    end

    test "rejects duplicate parameter names case-insensitively" do
      assert ContentDisposition.filename("attachment; filename=first.jpg; filename=second.jpg") ==
               nil

      assert ContentDisposition.filename("attachment; filename=first.jpg; FILENAME=second.jpg") ==
               nil

      assert ContentDisposition.filename(
               "attachment; filename*=UTF-8''first.jpg; filename*=UTF-8''second.jpg"
             ) == nil

      assert ContentDisposition.filename(
               "attachment; name=first; NAME=second; filename=photo.jpg"
             ) == nil
    end

    test "rejects invalid filename* syntax" do
      invalid_values = [
        ~s("UTF-8''photo.jpg"),
        "UTF-8''foo*bar.jpg",
        "UTF-8''foo'bar.jpg",
        "UTF-8''føø.jpg"
      ]

      for value <- invalid_values do
        assert ContentDisposition.filename("attachment; filename*=#{value}") == nil
      end
    end

    test "falls back to filename when filename* uses invalid syntax" do
      assert ContentDisposition.filename(
               ~s(attachment; filename="fallback.jpg"; filename*="UTF-8''photo.jpg")
             ) == "fallback.jpg"
    end

    test "returns nil when filename* is invalid and no filename fallback exists" do
      assert ContentDisposition.filename("attachment; filename*=UTF-8''bad%ZZ.jpg") == nil
      assert ContentDisposition.filename("attachment; filename*=UTF-8''bad%FF.jpg") == nil
      assert ContentDisposition.filename("attachment; filename*=UTF-16''photo.jpg") == nil
      assert ContentDisposition.filename("attachment; filename*=UTF-8''") == nil
      assert ContentDisposition.filename("attachment; filename*=UTF-8''photo%00.jpg") == nil
      assert ContentDisposition.filename("attachment; filename*=UTF-8''photo%09.jpg") == nil
      assert ContentDisposition.filename("attachment; filename*=UTF-8''photo%0D%0A.jpg") == nil
      assert ContentDisposition.filename("attachment; filename*=UTF-8''photo%7F.jpg") == nil
      assert ContentDisposition.filename("attachment; filename*=UTF-8''photo%C2%85.jpg") == nil
      assert ContentDisposition.filename("attachment; filename*=ISO-8859-1''photo%85.jpg") == nil
      assert ContentDisposition.filename("attachment; filename*=UTF-8''..%2Fsecret.txt") == nil
      assert ContentDisposition.filename("attachment; filename*=UTF-8''..%5Csecret.txt") == nil
    end

    test "rejects malformed headers instead of partially matching them" do
      assert ContentDisposition.filename(~s(attachment; filename="unterminated.jpg)) == nil
      assert ContentDisposition.filename(~s(attachment; filename="photo.jpg"; invalid)) == nil
      assert ContentDisposition.filename("attachment; filename=") == nil
      assert ContentDisposition.filename("filename=photo.jpg") == nil
      assert ContentDisposition.filename(~s(attachment filename="photo.jpg")) == nil
      assert ContentDisposition.filename(~s(attachment; = "photo.jpg")) == nil
    end

    test "rejects control characters and header injection" do
      assert ContentDisposition.filename("attachment; filename=\"photo\r\n.jpg\"") == nil
      assert ContentDisposition.filename("attachment; filename=\"photo\0.jpg\"") == nil
      assert ContentDisposition.filename("attachment\r\n; filename=photo.jpg") == nil
      assert ContentDisposition.filename("attachment; file\r\nname=photo.jpg") == nil
    end

    test "returns nil without a filename parameter" do
      assert ContentDisposition.filename("attachment") == nil
      assert ContentDisposition.filename("inline; name=file") == nil
      assert ContentDisposition.filename(nil) == nil
      assert ContentDisposition.filename(%{}) == nil
    end
  end
end
