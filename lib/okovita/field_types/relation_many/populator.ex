defmodule Okovita.FieldTypes.RelationMany.Populator do
  @moduledoc """
  Populator for the relation_many field type.
  """
  @behaviour Okovita.FieldTypes.Populator

  import Ecto.Query

  import Okovita.Content.Entries.Utils, only: [is_uuid?: 1]

  @impl true
  def population_target, do: :entry

  @impl true
  def extract_references(ids) when is_list(ids) do
    Enum.filter(ids, fn id -> is_binary(id) and is_uuid?(id) end)
  end

  def extract_references(_), do: []

  @impl true
  def populate(ids, entities_map, _opts) when is_list(ids) do
    valid_ids = Enum.filter(ids, &is_uuid?/1)

    valid_ids
    |> Enum.map(&Map.get(entities_map, &1))
    |> Enum.reject(&is_nil/1)
  end

  def populate(value, _entities_map, _opts), do: value

  @impl true
  def reverse_lookup_query(key, parent_id, acc) do
    json_array = Jason.encode!([parent_id])
    dynamic([e], fragment("?->? @> ?::jsonb", e.data, ^key, ^json_array) or ^acc)
  end
end
