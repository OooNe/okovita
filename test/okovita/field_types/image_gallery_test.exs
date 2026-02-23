defmodule Okovita.FieldTypes.ImageGalleryTest do
  use ExUnit.Case, async: true

  alias Okovita.FieldTypes.ImageGallery

  describe "primitive_type/0" do
    test "returns {:array, :map}" do
      assert {:array, :map} = ImageGallery.primitive_type()
    end
  end

  describe "cast/1" do
    test "casts list of UUID strings" do
      assert {:ok,
              [%{"media_id" => "uuid-1", "index" => 0}, %{"media_id" => "uuid-2", "index" => 1}]} =
               ImageGallery.cast(["uuid-1", "uuid-2"])
    end

    test "casts list of string-key maps" do
      input = [%{"media_id" => "uuid-1", "index" => 0}]
      assert {:ok, [%{"media_id" => "uuid-1", "index" => 0}]} = ImageGallery.cast(input)
    end

    test "casts list of atom-key maps" do
      input = [%{media_id: "uuid-1", index: 0}]
      assert {:ok, [%{"media_id" => "uuid-1", "index" => 0}]} = ImageGallery.cast(input)
    end

    test "accepts nil as empty list" do
      assert {:ok, []} = ImageGallery.cast(nil)
    end

    test "rejects non-list" do
      assert :error = ImageGallery.cast("not-a-list")
    end

    test "filters out nil items" do
      assert {:ok, [%{"media_id" => "uuid-1", "index" => 0}]} =
               ImageGallery.cast(["uuid-1", nil])
    end

    test "re-indexes correctly after filtering" do
      input = ["uuid-1", nil, "uuid-2"]
      {:ok, result} = ImageGallery.cast(input)
      assert Enum.map(result, & &1["index"]) == [0, 1]
    end
  end

  describe "editor_component/0" do
    test "returns ImageGallery.Editor" do
      assert ImageGallery.editor_component() == Okovita.FieldTypes.ImageGallery.Editor
    end
  end

  describe "normalize/1" do
    test "returns [] for nil" do
      assert [] == ImageGallery.normalize(nil)
    end

    test "returns [] for empty list" do
      assert [] == ImageGallery.normalize([])
    end

    test "normalizes list of UUID strings" do
      result = ImageGallery.normalize(["uuid-1", "uuid-2"])

      assert [%{"media_id" => "uuid-1", "index" => 0}, %{"media_id" => "uuid-2", "index" => 1}] =
               result
    end

    test "preserves existing metadata like url" do
      input = [%{"media_id" => "uuid-1", "index" => 0, "url" => "https://a.jpg"}]
      [item] = ImageGallery.normalize(input)
      assert item["url"] == "https://a.jpg"
    end

    test "handles atom-key maps" do
      input = [%{media_id: "uuid-1", index: 0}]
      [item] = ImageGallery.normalize(input)
      assert item["media_id"] == "uuid-1"
    end

    test "handles legacy image_url key" do
      input = [%{"image_url" => "uuid-1", "index" => 0}]
      [item] = ImageGallery.normalize(input)
      assert item["media_id"] == "uuid-1"
      refute Map.has_key?(item, "image_url")
    end

    test "returns [] for non-list" do
      assert [] == ImageGallery.normalize("not-a-list")
    end
  end

  describe "remove_item/2" do
    test "removes item at index and re-indexes" do
      items = [
        %{"media_id" => "uuid-1", "index" => 0},
        %{"media_id" => "uuid-2", "index" => 1},
        %{"media_id" => "uuid-3", "index" => 2}
      ]

      result = ImageGallery.remove_item(items, 1)

      assert length(result) == 2
      assert Enum.map(result, & &1["media_id"]) == ["uuid-1", "uuid-3"]
      assert Enum.map(result, & &1["index"]) == [0, 1]
    end

    test "removing last item" do
      items = [%{"media_id" => "uuid-1", "index" => 0}]
      assert [] == ImageGallery.remove_item(items, 0)
    end
  end

  describe "merge_sort/2" do
    test "applies new order from sorted_ids" do
      existing = [
        %{"media_id" => "uuid-1", "index" => 0, "url" => "https://a.jpg"},
        %{"media_id" => "uuid-2", "index" => 1, "url" => "https://b.jpg"}
      ]

      result = ImageGallery.merge_sort(existing, ["uuid-2", "uuid-1"])

      assert Enum.map(result, & &1["media_id"]) == ["uuid-2", "uuid-1"]
      assert Enum.map(result, & &1["index"]) == [0, 1]
    end

    test "preserves metadata from existing during reorder" do
      existing = [%{"media_id" => "uuid-1", "index" => 0, "url" => "https://a.jpg"}]
      [item] = ImageGallery.merge_sort(existing, ["uuid-1"])
      assert item["url"] == "https://a.jpg"
    end
  end
end
