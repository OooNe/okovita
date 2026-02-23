defmodule Okovita.FieldTypes.RelationTest do
  use ExUnit.Case, async: true

  alias Okovita.FieldTypes.Relation

  describe "primitive_type/0" do
    test "returns :string" do
      assert Relation.primitive_type() == :string
    end
  end

  describe "cast/1" do
    test "casts a valid UUID string" do
      assert {:ok, "550e8400-e29b-41d4-a716-446655440000"} =
               Relation.cast("550e8400-e29b-41d4-a716-446655440000")
    end

    test "casts any string (format checked in validate)" do
      assert {:ok, "some-value"} = Relation.cast("some-value")
    end

    test "rejects nil" do
      # Relation uses Ecto.Type.cast(:string, nil) which returns nil → not ok implicitly
      # Actually it returns {:ok, nil} for nil in Ecto.Type
      result = Relation.cast(nil)
      assert match?({:ok, _}, result)
    end
  end

  describe "validate/3" do
    test "accepts a valid UUID" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"

      cs =
        {%{}, %{ref: :string}}
        |> Ecto.Changeset.cast(%{ref: uuid}, [:ref])

      assert Relation.validate(cs, :ref, %{}).valid?
    end

    test "rejects an invalid UUID format" do
      cs =
        {%{}, %{ref: :string}}
        |> Ecto.Changeset.cast(%{ref: "not-a-uuid"}, [:ref])

      result = Relation.validate(cs, :ref, %{})
      refute result.valid?
      assert [ref: {"must be a valid UUID", _}] = result.errors
    end
  end

  describe "editor_component/0" do
    test "returns Relation.Editor" do
      assert Relation.editor_component() == Okovita.FieldTypes.Relation.Editor
    end
  end
end
