defmodule Okovita.FieldTypes.RegistryTest do
  use ExUnit.Case, async: true

  alias Okovita.FieldTypes.Registry

  describe "get!/1" do
    test "returns module for valid type name" do
      assert Registry.get!("text") == Okovita.FieldTypes.Types.Text
      assert Registry.get!("textarea") == Okovita.FieldTypes.Types.Textarea
      assert Registry.get!("number") == Okovita.FieldTypes.Types.Number
      assert Registry.get!("integer") == Okovita.FieldTypes.Types.Integer
      assert Registry.get!("boolean") == Okovita.FieldTypes.Types.Boolean
      assert Registry.get!("enum") == Okovita.FieldTypes.Types.Enum
      assert Registry.get!("date") == Okovita.FieldTypes.Types.Date
      assert Registry.get!("datetime") == Okovita.FieldTypes.Types.Datetime
    end

    test "raises for unknown type name" do
      assert_raise ArgumentError, ~r/Unknown field type: "unknown"/, fn ->
        Registry.get!("unknown")
      end
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
      assert types == Enum.sort(types)
      assert length(types) == 9
    end
  end
end
