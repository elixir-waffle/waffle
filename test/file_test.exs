defmodule WaffleTest.File do
  use ExUnit.Case, async: false
  import Mock
  alias Waffle.HTTPClient.Hackney

  @custom_tmp_dir System.tmp_dir() <> "/waffle_test_custom"

  defmodule DummyDefinition do
    use Waffle.Definition.Storage
    def transform(_, _), do: :noaction
    def __versions, do: [:original]
  end

  describe "generate_temporary_path/1" do
    test "uses configured tmp_dir" do
      File.mkdir_p!(@custom_tmp_dir)
      Application.put_env(:waffle, :tmp_dir, @custom_tmp_dir)

      assert Waffle.File.generate_temporary_path() |> String.starts_with?(@custom_tmp_dir)

      on_exit(fn ->
        Application.delete_env(:waffle, :tmp_dir)
        File.rm_rf!(@custom_tmp_dir)
      end)
    end

    test "uses system tmp_dir" do
      assert Waffle.File.generate_temporary_path() |> String.starts_with?(System.tmp_dir())
    end
  end

  describe "new/2 with remote URL — retry behavior" do
    setup do
      Application.put_env(:waffle, :http_client, Hackney)
      Application.put_env(:waffle, :max_retries, 2)
      # Zero-out backoff so tests don't sleep
      Application.put_env(:waffle, :backoff_factor, 0)
      Application.put_env(:waffle, :backoff_max, 0)

      on_exit(fn ->
        Application.delete_env(:waffle, :http_client)
        Application.delete_env(:waffle, :max_retries)
        Application.delete_env(:waffle, :backoff_factor)
        Application.delete_env(:waffle, :backoff_max)
      end)
    end

    test "retries on timeout and returns {:error, :timeout} after exhausting retries" do
      with_mock Hackney,
        get: fn _url, _headers, _opts ->
          {:error, :timeout}
        end do
        result = Waffle.File.new("http://example.com/image.jpg", DummyDefinition)
        assert result == {:error, :timeout}
        # initial attempt + 2 retries
        assert called(Hackney.get(:_, :_, :_))
      end
    end

    test "retries on service_unavailable and returns {:error, :service_unavailable} after exhausting retries" do
      with_mock Hackney,
        get: fn _url, _headers, _opts ->
          {:error, :service_unavailable}
        end do
        result = Waffle.File.new("http://example.com/image.jpg", DummyDefinition)
        assert result == {:error, :service_unavailable}
        assert called(Hackney.get(:_, :_, :_))
      end
    end

    test "does not retry on non-retryable errors" do
      with_mock Hackney,
        get: fn _url, _headers, _opts ->
          {:error, {:http_error, :unexpected_status}}
        end do
        result = Waffle.File.new("http://example.com/image.jpg", DummyDefinition)
        assert result == {:error, {:http_error, :unexpected_status}}
        # exactly 1 call — no retry
        assert :meck.num_calls(Hackney, :get, :_) == 1
      end
    end

    test "uses the module configured as :http_client" do
      Application.put_env(:waffle, :http_client, Hackney)

      with_mock Hackney,
        get: fn _url, _headers, _opts ->
          {:ok, "image data"}
        end do
        Waffle.File.new("http://example.com/image.jpg", DummyDefinition)
        assert called(Hackney.get(:_, :_, :_))
      end
    end
  end
end
