defmodule Okovita.FieldTypes.Types.ImageTest do
  use ExUnit.Case, async: true
  alias Okovita.FieldTypes.Types.Image
  import Ecto.Changeset

  describe "primitive_type/0" do
    test "returns :string" do
      assert Image.primitive_type() == :string
    end
  end

  describe "cast/1" do
    test "casts valid strings" do
      assert Image.cast("https://example.com/image.png") == {:ok, "https://example.com/image.png"}

      assert Image.cast("   https://example.com/image.png   ") ==
               {:ok, "https://example.com/image.png"}
    end

    test "casts empty strings to nil" do
      assert Image.cast("") == {:ok, nil}
      assert Image.cast("   ") == {:ok, nil}
    end

    test "casts nil to nil" do
      assert Image.cast(nil) == {:ok, nil}
    end

    test "returns :error for non-strings" do
      assert Image.cast(123) == :error
      assert Image.cast(%{}) == :error
    end
  end

  describe "validate/3" do
    setup do
      # Create a dummy changeset for testing
      types = %{image: :string}
      changeset = cast({%{}, types}, %{image: "https://example.com/image.png"}, [:image])
      {:ok, changeset: changeset}
    end

    test "validates proper URLs", %{changeset: changeset} do
      result = Image.validate(changeset, :image, %{})
      assert result.valid?
    end

    test "adds error for invalid URLs" do
      types = %{image: :string}
      changeset = cast({%{}, types}, %{image: "not-a-url"}, [:image])

      result = Image.validate(changeset, :image, %{})
      refute result.valid?
      assert "must be a valid URL" in errors_on(result).image
    end

    test "respects max_length option", %{changeset: changeset} do
      # URL is 29 chars long
      result = Image.validate(changeset, :image, %{"max_length" => 20})
      refute result.valid?
      assert "should be at most 20 character(s)" in errors_on(result).image

      result_valid = Image.validate(changeset, :image, %{"max_length" => 50})
      assert result_valid.valid?
    end
  end

  # Helper to extract errors
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
