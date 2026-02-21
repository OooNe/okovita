defmodule Okovita.FieldTypes.Types.ImageGallery do
  @moduledoc """
  Image Gallery field type. Stores an array of maps representing images.
  Each map has at least %{"image_url" => string, "index" => integer}.
  """
  @behaviour Okovita.FieldTypes.Behaviour

  import Ecto.Changeset

  @impl true
  def primitive_type, do: {:array, :map}

  @impl true
  def cast(value) when is_list(value) do
    # Gracefully handle upgrades from lists of strings to lists of maps
    cleaned =
      value
      |> Enum.reject(&is_nil/1)
      |> Enum.with_index()
      |> Enum.map(fn
        {item, idx} when is_binary(item) ->
          %{"image_url" => String.trim(item), "index" => idx}

        {%{"image_url" => url} = item, idx} when is_binary(url) ->
          # Ensure index is an integer
          index =
            case Map.get(item, "index", idx) do
              i when is_integer(i) -> i
              s when is_binary(s) -> String.to_integer(s)
              _ -> idx
            end

          Map.merge(item, %{"image_url" => String.trim(url), "index" => index})

        {%{image_url: url} = item, idx} when is_binary(url) ->
          # Handle atom keys just in case
          index =
            case Map.get(item, :index, idx) do
              i when is_integer(i) -> i
              s when is_binary(s) -> String.to_integer(s)
              _ -> idx
            end

          item
          |> Map.put("image_url", String.trim(url))
          |> Map.put("index", index)
          |> Map.drop([:image_url, :index])

        _ ->
          nil
      end)
      |> Enum.reject(fn item -> is_nil(item) || item["image_url"] == "" end)
      |> Enum.sort_by(& &1["index"])
      # Re-index to ensure contiguous sequential index
      |> Enum.with_index()
      |> Enum.map(fn {item, correct_idx} -> Map.put(item, "index", correct_idx) end)

    {:ok, cleaned}
  end

  def cast(nil), do: {:ok, []}
  def cast(_), do: :error

  @impl true
  def validate(changeset, field_name, options) do
    # Validate each URL in the array of maps
    changeset =
      validate_change(changeset, field_name, fn _, items ->
        invalid_urls =
          Enum.reject(items, fn %{"image_url" => url} ->
            is_binary(url) && Regex.match?(~r/^https?:\/\//, url)
          end)

        if invalid_urls == [] do
          []
        else
          [{field_name, "contain invalid URLs"}]
        end
      end)

    # Validate max items
    changeset =
      if max_items = options["max_items"] do
        validate_length(changeset, field_name, max: max_items)
      else
        changeset
      end

    # Validate min items
    if min_items = options["min_items"] do
      validate_length(changeset, field_name, min: min_items)
    else
      changeset
    end
  end
end
