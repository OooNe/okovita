defmodule Okovita.Pipeline.Sync.SlugifyTest do
  use ExUnit.Case, async: true

  alias Okovita.Pipeline.Sync.Slugify

  describe "apply/2" do
    test "converts to lowercase slug" do
      assert {:ok, "hello-world"} = Slugify.apply("Hello World", %{})
    end

    test "replaces spaces and special chars with hyphens" do
      assert {:ok, "foo-bar-baz"} = Slugify.apply("Foo  Bar  Baz", %{})
      assert {:ok, "hello-world"} = Slugify.apply("hello_world", %{})
    end

    test "strips non-alphanumeric characters" do
      assert {:ok, "hello-world"} = Slugify.apply("Hello, World!", %{})
    end

    test "collapses multiple hyphens" do
      assert {:ok, "a-b"} = Slugify.apply("a---b", %{})
    end

    test "trims leading/trailing hyphens" do
      assert {:ok, "hello"} = Slugify.apply(" -hello- ", %{})
    end

    test "passes through non-string values" do
      assert {:ok, 42} = Slugify.apply(42, %{})
      assert {:ok, nil} = Slugify.apply(nil, %{})
    end
  end
end
