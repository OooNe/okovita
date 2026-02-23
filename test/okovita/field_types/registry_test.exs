defmodule Okovita.FieldTypes.RegistryTest do
  use ExUnit.Case, async: true

  alias Okovita.FieldTypes.Registry

  describe "get!/1" do
    test "returns new canonical module for valid type name" do
      assert Registry.get!("text") == Okovita.FieldTypes.Text
      assert Registry.get!("textarea") == Okovita.FieldTypes.Textarea
      assert Registry.get!("number") == Okovita.FieldTypes.Number
      assert Registry.get!("integer") == Okovita.FieldTypes.Integer
      assert Registry.get!("boolean") == Okovita.FieldTypes.Boolean
      assert Registry.get!("enum") == Okovita.FieldTypes.Enum
      assert Registry.get!("date") == Okovita.FieldTypes.Date
      assert Registry.get!("datetime") == Okovita.FieldTypes.Datetime
      assert Registry.get!("relation") == Okovita.FieldTypes.Relation
      assert Registry.get!("image") == Okovita.FieldTypes.Image
      assert Registry.get!("image_gallery") == Okovita.FieldTypes.ImageGallery
    end

    test "raises for unknown type name" do
      assert_raise ArgumentError, ~r/Unknown field type: "unknown"/, fn ->
        Registry.get!("unknown")
      end
    end
  end

  describe "editor_for/1" do
    test "returns Editor module for known types" do
      assert Registry.editor_for("text") == Okovita.FieldTypes.Text.Editor
      assert Registry.editor_for("image") == Okovita.FieldTypes.Image.Editor
      assert Registry.editor_for("image_gallery") == Okovita.FieldTypes.ImageGallery.Editor
    end

    test "returns nil for unknown type" do
      assert Registry.editor_for("unknown") == nil
    end
  end

  describe "registered_types/0" do
    test "returns sorted list of all type names" do
      types = Registry.registered_types()
      assert is_list(types)
      assert "text" in types
      assert "boolean" in types
      assert "datetime" in types
      assert "relation" in types
      assert "image" in types
      assert "image_gallery" in types
      assert "rich_text" in types
      assert types == Enum.sort(types)
    end
  end
end
