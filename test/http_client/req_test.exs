defmodule WaffleTest.HTTPClient.ReqTest do
  use ExUnit.Case, async: false

  alias Waffle.HTTPClient.Req, as: ReqClient
  alias Waffle.HTTPClient.Response

  setup {Req.Test, :verify_on_exit!}

  setup do
    default_options = Req.default_options()
    Req.default_options(Keyword.put(default_options, :plug, {Req.Test, __MODULE__}))

    on_exit(fn -> Req.default_options(default_options) end)
  end

  describe "get/3" do
    test "with 200" do
      Req.Test.expect(__MODULE__, fn conn ->
        Plug.Conn.send_resp(conn, 200, "file content")
      end)

      assert ReqClient.get("http://example.com/file.jpg", [],
               max_body_length_bytes: 1024,
               receive_timeout_ms: 5_000,
               connect_timeout_ms: 10_000,
               max_redirects: nil
             ) ==
               {:ok, %Response{body: "file content", filename: nil}}
    end

    test "with 200 and json reponse"
    test "with 200 and content disponsition header"
    test "with 503"
    test "with non 200 as error"
    test "with conntect timeout"
    test "with receive timeout"
    test "with other exception"
  end
end
