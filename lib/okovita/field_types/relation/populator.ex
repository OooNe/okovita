defmodule Okovita.FieldTypes.Relation.Populator do
  @moduledoc """
  Populator for the relation field type.
  """
  @behaviour Okovita.FieldTypes.Populator

  import Ecto.Query

  import Okovita.Content.Entries.Utils, only: [is_uuid?: 1]

  @impl true
  def population_target, do: :entry

  @impl true
  def extract_references(id) when is_binary(id) do
    if is_uuid?(id), do: [id], else: []
  end

  def extract_references(_), do: []

  @impl true
  def populate(id, entities_map, _opts) when is_binary(id) do
    if is_uuid?(id) do
      Map.get(entities_map, id) || id
    else
      id
    end
  end

  def populate(value, _entities_map, _opts), do: value

  @impl true
  def reverse_lookup_query(key, parent_id, acc) do
    dynamic([e], fragment("?->>? = ?", e.data, ^key, ^parent_id) or ^acc)
  end
end
