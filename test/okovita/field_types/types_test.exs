defmodule Okovita.FieldTypes.TypesTest do
  use ExUnit.Case, async: true

  alias Okovita.FieldTypes.{Text, Textarea, Number, Boolean, Date, Datetime}
  alias Okovita.FieldTypes.Integer, as: IntegerType
  alias Okovita.FieldTypes.Enum, as: EnumType

  # ── Text ──────────────────────────────────────────────────────────

  describe "Text" do
    test "primitive_type is :string" do
      assert Text.primitive_type() == :string
    end

    test "casts valid strings" do
      assert {:ok, "hello"} = Text.cast("hello")
      assert {:ok, nil} = Text.cast(nil)
    end

    test "rejects non-strings" do
      assert :error = Text.cast(42)
      assert :error = Text.cast(true)
    end

    test "validates max_length" do
      cs =
        {%{}, %{title: :string}}
        |> Ecto.Changeset.cast(%{title: "too long"}, [:title])

      result = Text.validate(cs, :title, %{"max_length" => 3})
      refute result.valid?

      assert [title: {_, [count: 3, validation: :length, kind: :max, type: :string]}] =
               result.errors
    end

    test "skips validation when no max_length" do
      cs =
        {%{}, %{title: :string}}
        |> Ecto.Changeset.cast(%{title: "any length"}, [:title])

      assert Text.validate(cs, :title, %{}).valid?
    end

    test "editor_component/0 returns Text.Editor" do
      assert Text.editor_component() == Okovita.FieldTypes.Text.Editor
    end
  end

  # ── Textarea ──────────────────────────────────────────────────────

  describe "Textarea" do
    test "primitive_type is :string" do
      assert Textarea.primitive_type() == :string
    end

    test "casts and validates like Text" do
      assert {:ok, "body"} = Textarea.cast("body")
      assert :error = Textarea.cast(42)
    end

    test "editor_component/0 returns Textarea.Editor" do
      assert Textarea.editor_component() == Okovita.FieldTypes.Textarea.Editor
    end
  end

  # ── Number ────────────────────────────────────────────────────────

  describe "Number" do
    test "primitive_type is :float" do
      assert Number.primitive_type() == :float
    end

    test "casts floats, integers, and numeric strings" do
      assert {:ok, 3.14} = Number.cast(3.14)
      assert {:ok, 5.0} = Number.cast(5)
      assert {:ok, 1.5} = Number.cast("1.5")
      assert {:ok, nil} = Number.cast(nil)
    end

    test "rejects non-numeric" do
      assert :error = Number.cast("abc")
      assert :error = Number.cast(true)
    end

    test "validates min and max" do
      cs =
        {%{}, %{price: :float}}
        |> Ecto.Changeset.cast(%{price: -1.0}, [:price])

      result = Number.validate(cs, :price, %{"min" => 0})
      refute result.valid?

      cs2 =
        {%{}, %{price: :float}}
        |> Ecto.Changeset.cast(%{price: 200.0}, [:price])

      result2 = Number.validate(cs2, :price, %{"max" => 100})
      refute result2.valid?
    end
  end

  # ── Integer ───────────────────────────────────────────────────────

  describe "Integer" do
    test "primitive_type is :integer" do
      assert IntegerType.primitive_type() == :integer
    end

    test "casts integers, floats, and numeric strings" do
      assert {:ok, 42} = IntegerType.cast(42)
      assert {:ok, 3} = IntegerType.cast(3.9)
      assert {:ok, 7} = IntegerType.cast("7")
      assert {:ok, nil} = IntegerType.cast(nil)
    end

    test "rejects non-numeric" do
      assert :error = IntegerType.cast("abc")
    end

    test "validates min and max" do
      cs =
        {%{}, %{count: :integer}}
        |> Ecto.Changeset.cast(%{count: -5}, [:count])

      result = IntegerType.validate(cs, :count, %{"min" => 0})
      refute result.valid?
    end
  end

  # ── Boolean ───────────────────────────────────────────────────────

  describe "Boolean" do
    test "primitive_type is :boolean" do
      assert Boolean.primitive_type() == :boolean
    end

    test "casts booleans, strings, and integers" do
      assert {:ok, true} = Boolean.cast(true)
      assert {:ok, false} = Boolean.cast(false)
      assert {:ok, true} = Boolean.cast("true")
      assert {:ok, false} = Boolean.cast("false")
      assert {:ok, true} = Boolean.cast(1)
      assert {:ok, false} = Boolean.cast(0)
      assert {:ok, nil} = Boolean.cast(nil)
    end

    test "rejects invalid values" do
      assert :error = Boolean.cast("yes")
      assert :error = Boolean.cast(42)
    end

    test "validate is a no-op (inherited from Base)" do
      cs =
        {%{}, %{flag: :boolean}}
        |> Ecto.Changeset.cast(%{flag: true}, [:flag])

      assert Boolean.validate(cs, :flag, %{}).valid?
    end
  end

  # ── Enum ──────────────────────────────────────────────────────────

  describe "Enum" do
    test "primitive_type is :string" do
      assert EnumType.primitive_type() == :string
    end

    test "casts strings" do
      assert {:ok, "draft"} = EnumType.cast("draft")
      assert {:ok, nil} = EnumType.cast(nil)
      assert :error = EnumType.cast(42)
    end

    test "validates inclusion in one_of" do
      cs =
        {%{}, %{status: :string}}
        |> Ecto.Changeset.cast(%{status: "published"}, [:status])

      result = EnumType.validate(cs, :status, %{"one_of" => ["draft", "published", "archived"]})
      assert result.valid?

      result2 = EnumType.validate(cs, :status, %{"one_of" => ["draft", "archived"]})
      refute result2.valid?
    end

    test "adds error when one_of is missing" do
      cs =
        {%{}, %{status: :string}}
        |> Ecto.Changeset.cast(%{status: "draft"}, [:status])

      result = EnumType.validate(cs, :status, %{})
      refute result.valid?
      assert [status: {"enum field must define one_of", []}] = result.errors
    end
  end

  # ── Date ──────────────────────────────────────────────────────────

  describe "Date" do
    test "primitive_type is :date" do
      assert Date.primitive_type() == :date
    end

    test "casts ISO 8601 strings and Date structs" do
      assert {:ok, ~D[2026-01-15]} = Date.cast("2026-01-15")
      assert {:ok, ~D[2026-01-15]} = Date.cast(~D[2026-01-15])
      assert {:ok, nil} = Date.cast(nil)
    end

    test "rejects invalid dates" do
      assert :error = Date.cast("not-a-date")
      assert :error = Date.cast(42)
    end
  end

  # ── Datetime ──────────────────────────────────────────────────────

  describe "Datetime" do
    test "primitive_type is :utc_datetime" do
      assert Datetime.primitive_type() == :utc_datetime
    end

    test "casts ISO 8601 strings and DateTime structs" do
      {:ok, dt, _} = DateTime.from_iso8601("2026-01-15T10:30:00Z")
      assert {:ok, ^dt} = Datetime.cast("2026-01-15T10:30:00Z")
      assert {:ok, ^dt} = Datetime.cast(dt)
      assert {:ok, nil} = Datetime.cast(nil)
    end

    test "rejects invalid datetimes" do
      assert :error = Datetime.cast("not-a-datetime")
      assert :error = Datetime.cast(42)
    end
  end
end
