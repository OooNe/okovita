defmodule Okovita.FieldTypes.Image.Populator do
  @moduledoc """
  Populator for the image field type.
  """
  @behaviour Okovita.FieldTypes.Populator

  import Okovita.Content.Entries.Utils, only: [is_uuid?: 1]

  @impl true
  def population_target, do: :media

  @impl true
  def extract_references(value) do
    id = Okovita.FieldTypes.Image.extract_id(value)
    if is_binary(id) and is_uuid?(id), do: [id], else: []
  end

  @impl true
  def populate(id, media_map, _opts) when is_binary(id) do
    if is_uuid?(id) do
      Map.get(media_map, id) || id
    else
      id
    end
  end

  def populate(value, _media_map, _opts), do: value
end
