defmodule Okovita.FieldTypes.RichTextTest do
  use ExUnit.Case, async: true

  alias Okovita.FieldTypes.RichText

  describe "primitive_type/0" do
    test "returns :map" do
      assert RichText.primitive_type() == :map
    end
  end

  describe "cast/1" do
    test "accepts a map" do
      doc = %{"type" => "doc", "content" => []}
      assert {:ok, ^doc} = RichText.cast(doc)
    end

    test "accepts JSON string" do
      json = ~s({"type":"doc","content":[]})
      assert {:ok, %{"type" => "doc"}} = RichText.cast(json)
    end

    test "converts nil to empty map" do
      assert {:ok, %{}} = RichText.cast(nil)
    end

    test "rejects invalid JSON string" do
      assert :error = RichText.cast("not json")
    end

    test "rejects non-map, non-string" do
      assert :error = RichText.cast(42)
      assert :error = RichText.cast([])
    end
  end

  describe "validate/3" do
    test "is a no-op" do
      cs =
        {%{}, %{content: :map}}
        |> Ecto.Changeset.cast(%{content: %{}}, [:content])

      assert RichText.validate(cs, :content, %{}).valid?
    end
  end

  describe "editor_component/0" do
    test "returns RichText.Editor" do
      assert RichText.editor_component() == Okovita.FieldTypes.RichText.Editor
    end
  end
end
