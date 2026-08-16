defmodule WaffleTest.HTTPClient.ReqTest do
  use ExUnit.Case, async: false

  alias Waffle.HTTPClient
  alias Waffle.HTTPClient

  setup {Req.Test, :verify_on_exit!}

  describe "get/3" do
    test "with 200" do
      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        Plug.Conn.send_resp(conn, 200, "file content")
      end)

      assert HTTPClient.Req.get(
               "http://example.com/file.jpg",
               [],
               Waffle.HTTPClient.Request.options()
             ) ==
               {:ok, %HTTPClient.Response{body: "file content", filename: nil}}
    end

    test "with 200 and json reponse" do
      json = %{"message" => "file content"}

      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        Req.Test.json(conn, json)
      end)

      assert HTTPClient.Req.get(
               "http://example.com/file.json",
               [],
               Waffle.HTTPClient.Request.options()
             ) ==
               {:ok, %HTTPClient.Response{body: Jason.encode!(json), filename: nil}}
    end

    test "with 200 and content disponsition header" do
      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        conn
        |> Plug.Conn.put_resp_header(
          "content-disposition",
          ~s(attachment; filename="photo.jpg")
        )
        |> Plug.Conn.send_resp(200, "file content")
      end)

      assert HTTPClient.Req.get(
               "http://example.com/file",
               [],
               Waffle.HTTPClient.Request.options()
             ) ==
               {:ok, %HTTPClient.Response{body: "file content", filename: "photo.jpg"}}
    end

    test "with 503" do
      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        Plug.Conn.send_resp(conn, 503, "service unavailable")
      end)

      assert {:error,
              %HTTPClient.Error{
                error: {:unexpected_status, 503},
                error_context: %Req.Response{status: 503, body: "service unavailable"},
                request: %Req.Request{}
              }} =
               HTTPClient.Req.get(
                 "http://example.com/file.jpg",
                 [],
                 Waffle.HTTPClient.Request.options()
               )
    end

    test "with non 200 as error" do
      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        Plug.Conn.send_resp(conn, 404, "not found")
      end)

      assert {:error,
              %HTTPClient.Error{
                error: {:unexpected_status, 404},
                error_context: %Req.Response{status: 404, body: "not found"},
                request: %Req.Request{}
              }} =
               HTTPClient.Req.get(
                 "http://example.com/missing.jpg",
                 [],
                 Waffle.HTTPClient.Request.options()
               )
    end

    test "with connect timeout" do
      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      options =
        Waffle.HTTPClient.Request.options()
        |> Keyword.put(:connect_timeout_ms, 100)

      assert {:error,
              %HTTPClient.Error{
                error: :timeout,
                error_context: %Req.TransportError{reason: :timeout},
                request: %Req.Request{options: %{connect_options: [timeout: 100]}}
              }} =
               HTTPClient.Req.get("http://example.com/file.jpg", [], options)
    end

    test "with receive timeout" do
      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      options =
        Waffle.HTTPClient.Request.options()
        |> Keyword.put(:receive_timeout_ms, 100)

      assert {:error,
              %HTTPClient.Error{
                error: :timeout,
                error_context: %Req.TransportError{reason: :timeout},
                request: %Req.Request{options: %{receive_timeout: 100}}
              }} =
               HTTPClient.Req.get("http://example.com/file.jpg", [], options)
    end

    test "with other exception" do
      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error,
              %HTTPClient.Error{
                error: :http_client,
                error_context: %Req.TransportError{reason: :econnrefused},
                request: %Req.Request{}
              }} =
               HTTPClient.Req.get(
                 "http://example.com/file.jpg",
                 [],
                 Waffle.HTTPClient.Request.options()
               )
    end

    test "with content-length header larger than allowed" do
      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-length", "1025")
        |> Plug.Conn.send_resp(200, "file content")
      end)

      options =
        Waffle.HTTPClient.Request.options()
        |> Keyword.put(:max_body_length_bytes, 1024)

      assert {:error,
              %HTTPClient.Error{
                error: :response_body_limit_exceeded,
                error_context: %HTTPClient.ResponseBodyLimitError{limit_bytes: 1024},
                request: %Req.Request{}
              }} =
               HTTPClient.Req.get("http://example.com/file.jpg", [], options)
    end

    test "with streamed body larger than allowed" do
      Req.Test.expect(Waffle.HTTPClient.Req, fn conn ->
        conn = Plug.Conn.send_chunked(conn, 200)

        {:ok, conn} = Plug.Conn.chunk(conn, "123")
        {:ok, conn} = Plug.Conn.chunk(conn, "456")

        conn
      end)

      options =
        Waffle.HTTPClient.Request.options()
        |> Keyword.put(:max_body_length_bytes, 5)

      assert {:error,
              %HTTPClient.Error{
                error: :response_body_limit_exceeded,
                error_context: %HTTPClient.ResponseBodyLimitError{limit_bytes: 5},
                request: %Req.Request{}
              }} =
               HTTPClient.Req.get("http://example.com/file.jpg", [], options)
    end
  end
end
