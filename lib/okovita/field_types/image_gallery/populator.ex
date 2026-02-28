defmodule Okovita.FieldTypes.ImageGallery.Populator do
  @moduledoc """
  Populator for the image_gallery field type.
  """
  @behaviour Okovita.FieldTypes.Populator

  import Okovita.Content.Entries.Utils, only: [is_uuid?: 1]

  @impl true
  def population_target, do: :media

  @impl true
  def extract_references(gallery) when is_list(gallery) do
    Enum.flat_map(gallery, fn
      %{"media_id" => id} when is_binary(id) ->
        if is_uuid?(id), do: [id], else: []

      _ ->
        []
    end)
  end

  def extract_references(_), do: []

  @impl true
  def populate(gallery, media_map, _opts) when is_list(gallery) do
    Enum.map(gallery, fn
      %{"media_id" => id} = item when is_binary(id) ->
        media = if is_uuid?(id), do: Map.get(media_map, id)

        if media do
          Map.put(item, "media", media)
        else
          item
        end

      item ->
        item
    end)
  end

  def populate(value, _media_map, _opts), do: value
end
