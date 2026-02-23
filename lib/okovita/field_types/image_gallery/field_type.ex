defmodule Okovita.FieldTypes.ImageGallery do
  @moduledoc """
  Image Gallery field type. Stores an array of maps representing images.
  Each map has at least `%{"media_id" => string, "index" => integer}`.
  """
  use Okovita.FieldTypes.Base

  import Ecto.Changeset

  @impl true
  def primitive_type, do: {:array, :map}

  @impl true
  def cast(value) when is_list(value) do
    cleaned =
      value
      |> Enum.reject(&is_nil/1)
      |> Enum.with_index()
      |> Enum.map(fn
        {item, idx} when is_binary(item) ->
          %{"media_id" => String.trim(item), "index" => idx}

        {%{"media_id" => id} = item, idx} when is_binary(id) ->
          index =
            case Map.get(item, "index", idx) do
              i when is_integer(i) -> i
              s when is_binary(s) -> String.to_integer(s)
              _ -> idx
            end

          Map.merge(item, %{"media_id" => String.trim(id), "index" => index})

        {%{"image_url" => id} = item, idx} when is_binary(id) ->
          index =
            case Map.get(item, "index", idx) do
              i when is_integer(i) -> i
              s when is_binary(s) -> String.to_integer(s)
              _ -> idx
            end

          item
          |> Map.put("media_id", String.trim(id))
          |> Map.put("index", index)
          |> Map.drop(["image_url"])

        _ ->
          nil
      end)
      |> Enum.reject(fn item -> is_nil(item) || item["media_id"] == "" end)
      |> Enum.sort_by(& &1["index"])
      |> Enum.with_index()
      |> Enum.map(fn {item, correct_idx} -> Map.put(item, "index", correct_idx) end)

    {:ok, cleaned}
  end

  def cast(nil), do: {:ok, []}
  def cast(_), do: :error

  @impl true
  def validate(changeset, field_name, options) do
    changeset =
      validate_change(changeset, field_name, fn _, items ->
        invalid =
          Enum.reject(items, fn %{"media_id" => id} ->
            is_binary(id) && Ecto.UUID.cast(id) != :error
          end)

        if invalid == [], do: [], else: [{field_name, "contain invalid media references"}]
      end)

    changeset =
      if max = options["max_items"],
        do: validate_length(changeset, field_name, max: max),
        else: changeset

    if min = options["min_items"],
      do: validate_length(changeset, field_name, min: min),
      else: changeset
  end

  # ── Normalization helpers ─────────────────────────────────────────────────────

  @doc """
  Normalizes a raw image_gallery value into a canonical sorted list of maps.

  Each item in the result has at minimum `%{"media_id" => uuid, "index" => integer}`.
  URL and file_name are preserved when available.

  ## Examples

      iex> Okovita.FieldTypes.ImageGallery.normalize(nil)
      []

      iex> Okovita.FieldTypes.ImageGallery.normalize(["uuid-1", "uuid-2"])
      [%{"media_id" => "uuid-1", "index" => 0}, %{"media_id" => "uuid-2", "index" => 1}]
  """
  @spec normalize(any()) :: [map()]
  def normalize(nil), do: []
  def normalize([]), do: []

  def normalize(items) when is_list(items) do
    items
    |> Enum.with_index()
    |> Enum.map(&normalize_item/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1["index"])
    |> Enum.with_index()
    |> Enum.map(fn {item, i} -> Map.put(item, "index", i) end)
  end

  def normalize(_), do: []

  @doc """
  Removes a gallery item at the given index and re-indexes the remaining items.
  """
  @spec remove_item([map()], non_neg_integer()) :: [map()]
  def remove_item(items, index) when is_list(items) do
    items
    |> Enum.with_index()
    |> Enum.map(fn
      {id, idx} when is_binary(id) -> %{"media_id" => id, "index" => idx}
      {map, _} when is_map(map) -> map
    end)
    |> List.delete_at(index)
    |> Enum.sort_by(&(&1["index"] || 0))
    |> Enum.with_index()
    |> Enum.map(fn {item, i} -> Map.put(item, "index", i) end)
  end

  @doc """
  Merges existing gallery data with a new ordered list of IDs from the DOM (e.g. SortableJS).

  Preserves enriched metadata (URL, file_name) from `existing_data` while applying
  the new ordering from `sorted_ids`.
  """
  @spec merge_sort([map()], [String.t()]) :: [map()]
  def merge_sort(existing_data, sorted_ids) when is_list(sorted_ids) do
    sorted_ids
    |> Enum.with_index()
    |> Enum.map(fn {id, i} ->
      existing_item =
        Enum.find(existing_data, fn item ->
          (is_map(item) && item["media_id"] == id) || (is_binary(item) && item == id)
        end)

      base =
        case existing_item do
          nil -> %{}
          map when is_map(map) -> map
          _ -> %{}
        end

      Map.merge(base, %{"media_id" => id, "index" => i})
    end)
  end

  # ── Private ───────────────────────────────────────────────────────────────────

  defp normalize_item({item, idx}) when is_binary(item) and item != "" do
    %{"media_id" => String.trim(item), "index" => idx}
  end

  defp normalize_item({%{"media_id" => id} = item, idx}) when is_binary(id) do
    index = parse_index(Map.get(item, "index", idx), idx)
    Map.put(item, "index", index)
  end

  # Legacy: image_url key
  defp normalize_item({%{"image_url" => id} = item, idx}) when is_binary(id) do
    index = parse_index(Map.get(item, "index", idx), idx)

    item
    |> Map.put("media_id", String.trim(id))
    |> Map.put("index", index)
    |> Map.drop(["image_url"])
  end

  defp normalize_item(_), do: nil

  defp parse_index(i, _) when is_integer(i), do: i
  defp parse_index(s, _) when is_binary(s), do: String.to_integer(s)
  defp parse_index(_, default), do: default
end
