defmodule Okovita.FieldTypes.RelationManyTest do
  use ExUnit.Case, async: true

  alias Okovita.FieldTypes.RelationMany

  @valid_uuid "550e8400-e29b-41d4-a716-446655440000"
  @another_uuid "6ba7b810-9dad-11d1-80b4-00c04fd430c8"

  describe "primitive_type/0" do
    test "returns {:array, :string}" do
      assert RelationMany.primitive_type() == {:array, :string}
    end
  end

  describe "cast/1" do
    test "casts a list of valid UUID strings" do
      assert {:ok, [@valid_uuid, @another_uuid]} =
               RelationMany.cast([@valid_uuid, @another_uuid])
    end

    test "trims whitespace from each UUID" do
      assert {:ok, [@valid_uuid]} = RelationMany.cast(["  #{@valid_uuid}  "])
    end

    test "filters out nil values" do
      assert {:ok, [@valid_uuid]} = RelationMany.cast([@valid_uuid, nil])
    end

    test "filters out empty strings" do
      assert {:ok, [@valid_uuid]} = RelationMany.cast([@valid_uuid, ""])
    end

    test "filters out blank strings" do
      assert {:ok, [@valid_uuid]} = RelationMany.cast([@valid_uuid, "   "])
    end

    test "cast nil returns empty list" do
      assert {:ok, []} = RelationMany.cast(nil)
    end

    test "cast empty list returns empty list" do
      assert {:ok, []} = RelationMany.cast([])
    end

    test "rejects a non-list scalar" do
      assert :error = RelationMany.cast("not-a-list")
    end

    test "rejects a non-list map" do
      assert :error = RelationMany.cast(%{id: @valid_uuid})
    end
  end

  describe "validate/3" do
    defp make_cs(ids) do
      {%{}, %{refs: {:array, :string}}}
      |> Ecto.Changeset.cast(%{refs: ids}, [:refs])
    end

    test "accepts a list of valid UUIDs" do
      cs = make_cs([@valid_uuid, @another_uuid])
      assert RelationMany.validate(cs, :refs, %{}).valid?
    end

    test "rejects when any element is not a valid UUID" do
      cs = make_cs([@valid_uuid, "not-a-uuid"])
      result = RelationMany.validate(cs, :refs, %{})
      refute result.valid?
      assert [refs: {"all items must be valid UUIDs", _}] = result.errors
    end

    test "accepts empty list" do
      cs = make_cs([])
      assert RelationMany.validate(cs, :refs, %{}).valid?
    end

    test "validates max_items" do
      cs = make_cs([@valid_uuid, @another_uuid])
      result = RelationMany.validate(cs, :refs, %{"max_items" => 1})
      refute result.valid?
    end

    test "validates min_items" do
      cs = make_cs([])
      result = RelationMany.validate(cs, :refs, %{"min_items" => 1})
      refute result.valid?
    end

    test "passes when list size is within min/max bounds" do
      cs = make_cs([@valid_uuid])
      result = RelationMany.validate(cs, :refs, %{"min_items" => 1, "max_items" => 3})
      assert result.valid?
    end
  end

  describe "editor_component/0" do
    test "returns RelationMany.Editor" do
      assert RelationMany.editor_component() == Okovita.FieldTypes.RelationMany.Editor
    end
  end
end
