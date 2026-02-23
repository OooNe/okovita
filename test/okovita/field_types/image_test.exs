defmodule Okovita.FieldTypes.ImageTest do
  use ExUnit.Case, async: true

  alias Okovita.FieldTypes.Image

  describe "primitive_type/0" do
    test "returns :string" do
      assert Image.primitive_type() == :string
    end
  end

  describe "cast/1" do
    test "accepts a plain string" do
      assert {:ok, "uuid-123"} = Image.cast("uuid-123")
    end

    test "trims whitespace" do
      assert {:ok, "uuid-123"} = Image.cast("  uuid-123  ")
    end

    test "converts empty string to nil" do
      assert {:ok, nil} = Image.cast("")
      assert {:ok, nil} = Image.cast("   ")
    end

    test "accepts nil" do
      assert {:ok, nil} = Image.cast(nil)
    end

    test "rejects non-string" do
      assert :error = Image.cast(42)
      assert :error = Image.cast(%{})
    end
  end

  describe "editor_component/0" do
    test "returns Image.Editor" do
      assert Image.editor_component() == Okovita.FieldTypes.Image.Editor
    end
  end

  describe "extract_id/1" do
    test "extracts id from atom-key map" do
      assert "uuid-123" == Image.extract_id(%{id: "uuid-123", url: "https://..."})
    end

    test "extracts id from string-key map" do
      assert "uuid-123" == Image.extract_id(%{"id" => "uuid-123"})
    end

    test "returns bare string as-is" do
      assert "uuid-123" == Image.extract_id("uuid-123")
    end

    test "returns nil for nil" do
      assert nil == Image.extract_id(nil)
    end

    test "returns nil for empty string" do
      assert nil == Image.extract_id("")
    end

    test "returns nil for unrecognized shape" do
      assert nil == Image.extract_id(%{foo: "bar"})
    end
  end

  describe "extract_url/1" do
    test "extracts url from atom-key map" do
      assert "https://s3.example.com/photo.jpg" ==
               Image.extract_url(%{url: "https://s3.example.com/photo.jpg"})
    end

    test "extracts url from string-key map" do
      assert "https://s3.example.com/photo.jpg" ==
               Image.extract_url(%{"url" => "https://s3.example.com/photo.jpg"})
    end

    test "returns nil for nil" do
      assert nil == Image.extract_url(nil)
    end

    test "returns nil when no url key" do
      assert nil == Image.extract_url("just-an-id")
      assert nil == Image.extract_url(%{id: "uuid-123"})
    end
  end
end
