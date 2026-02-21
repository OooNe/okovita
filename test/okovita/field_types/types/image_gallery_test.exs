defmodule Okovita.FieldTypes.Types.ImageGalleryTest do
  use ExUnit.Case, async: true
  alias Okovita.FieldTypes.Types.ImageGallery
  import Ecto.Changeset

  describe "primitive_type/0" do
    test "returns {:array, :map}" do
      assert ImageGallery.primitive_type() == {:array, :map}
    end
  end

  describe "cast/1" do
    test "casts valid list of strings, trims, and converts to map format" do
      assert ImageGallery.cast(["  https://test.com/1.jpg  ", "https://test.com/2.jpg"]) ==
               {:ok,
                [
                  %{"image_url" => "https://test.com/1.jpg", "index" => 0},
                  %{"image_url" => "https://test.com/2.jpg", "index" => 1}
                ]}
    end

    test "casts maps and preserves custom index values sorting them" do
      input = [
        %{"image_url" => "https://test.com/2.jpg", "index" => 1},
        %{"image_url" => "https://test.com/1.jpg", "index" => 0}
      ]

      assert ImageGallery.cast(input) ==
               {:ok,
                [
                  %{"image_url" => "https://test.com/1.jpg", "index" => 0},
                  %{"image_url" => "https://test.com/2.jpg", "index" => 1}
                ]}
    end

    test "handles atom keys and normalizes" do
      input = [
        %{image_url: "https://test.com/1.jpg", index: 0}
      ]

      assert ImageGallery.cast(input) ==
               {:ok,
                [
                  %{"image_url" => "https://test.com/1.jpg", "index" => 0}
                ]}
    end

    test "rejects empty strings and nil values gracefully adjusting indexes" do
      assert ImageGallery.cast(["https://test.com/1.jpg", "", nil, "https://test.com/3.jpg"]) ==
               {:ok,
                [
                  %{"image_url" => "https://test.com/1.jpg", "index" => 0},
                  %{"image_url" => "https://test.com/3.jpg", "index" => 1}
                ]}
    end

    test "casts nil to empty list" do
      assert ImageGallery.cast(nil) == {:ok, []}
    end

    test "returns :error for non-lists" do
      assert ImageGallery.cast("https://test.com/1.jpg") == :error
      assert ImageGallery.cast(123) == :error
      assert ImageGallery.cast(%{}) == :error
    end
  end

  describe "validate/3" do
    setup do
      types = %{gallery: {:array, :map}}

      changeset =
        cast(
          {%{}, types},
          %{
            gallery: [
              %{"image_url" => "https://example.com/1.png", "index" => 0},
              %{"image_url" => "https://example.com/2.png", "index" => 1}
            ]
          },
          [
            :gallery
          ]
        )

      {:ok, changeset: changeset}
    end

    test "validates proper URLs", %{changeset: changeset} do
      result = ImageGallery.validate(changeset, :gallery, %{})
      assert result.valid?
    end

    test "adds error for invalid URLs" do
      types = %{gallery: {:array, :map}}

      changeset =
        cast(
          {%{}, types},
          %{
            gallery: [
              %{"image_url" => "not-a-url", "index" => 0},
              %{"image_url" => "https://good.com/val", "index" => 1}
            ]
          },
          [:gallery]
        )

      result = ImageGallery.validate(changeset, :gallery, %{})
      refute result.valid?
      assert "contain invalid URLs" in errors_on(result).gallery
    end

    test "respects max_items option", %{changeset: changeset} do
      result = ImageGallery.validate(changeset, :gallery, %{"max_items" => 1})
      refute result.valid?
      assert "should have at most 1 item(s)" in errors_on(result).gallery

      result_valid = ImageGallery.validate(changeset, :gallery, %{"max_items" => 5})
      assert result_valid.valid?
    end

    test "respects min_items option", %{changeset: changeset} do
      result = ImageGallery.validate(changeset, :gallery, %{"min_items" => 3})
      refute result.valid?
      assert "should have at least 3 item(s)" in errors_on(result).gallery

      result_valid = ImageGallery.validate(changeset, :gallery, %{"min_items" => 1})
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
