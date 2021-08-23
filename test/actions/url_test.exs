defmodule WaffleTest.Actions.Url do
  use ExUnit.Case, async: false
  import Mock

  defmodule DummyDefinition do
    use Waffle.Actions.Url
    use Waffle.Definition.Storage

    def __versions, do: [:original, :thumb, :skipped]
    def transform(:skipped, _), do: :skip
    def transform(_, _), do: :noaction
    def default_url(version, scope) when is_nil(scope), do: "dummy-#{version}"
    def default_url(version, scope), do: "dummy-#{version}-#{scope}"
    def __storage, do: Waffle.Storage.Local
  end

  test "delegates default_url generation to the definition when given a nil file" do
    assert DummyDefinition.url(nil) == "dummy-original"
    assert DummyDefinition.url(nil, :thumb) == "dummy-thumb"
    assert DummyDefinition.url({nil, :scope}, :thumb) == "dummy-thumb-scope"
  end

  test "handles skipped versions" do
    assert DummyDefinition.url("file.png", :skipped) == nil
  end

  test_with_mock "delegates url generation to the storage engine", Waffle.Storage.Local,
    [url: fn(DummyDefinition, :original, {%{file_name: "file.png"}, nil}, []) -> :ok end] do
    assert DummyDefinition.url("file.png") == :ok
  end

  test_with_mock "optional atom as a second argument specifies the version", Waffle.Storage.Local,
    [url: fn(DummyDefinition, :thumb, {%{file_name: "file.png"}, nil}, []) -> :ok end] do
    assert DummyDefinition.url("file.png", :thumb) == :ok
  end

  test_with_mock "optional list as a second argument specifies the options", Waffle.Storage.Local,
    [url: fn(DummyDefinition, :original, {%{file_name: "file.png"}, nil}, [signed: true, expires_in: 10]) -> :ok end] do
    assert DummyDefinition.url("file.png", signed: true, expires_in: 10) == :ok
  end

  test_with_mock "optional tuple for file including scope", Waffle.Storage.Local,
    [url: fn(DummyDefinition, :original, {%{file_name: "file.png"}, :scope}, []) -> :ok end] do
    assert DummyDefinition.url({"file.png", :scope}) == :ok
  end

  test_with_mock "optional tuple for file including scope 2", Waffle.Storage.Local,
    [url: fn
    (DummyDefinition, :original, {%{file_name: "file.png"}, :scope}, [signed: true]) -> :ok
    (DummyDefinition, :thumb, {%{file_name: "file.png"}, :scope}, [signed: true]) -> :ok
  end] do
    assert DummyDefinition.urls({"file.png", :scope}, signed: true) == %{original: :ok, thumb: :ok, skipped: nil}
  end
end
