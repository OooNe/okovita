defmodule Okovita.Content.Entries.Population do
  @moduledoc """
  Handles population of relation and media fields for entries.
  Replaces UUID references with full structs.
  """

  alias Okovita.Content.Entry
  alias Okovita.Content.Entries
  alias Okovita.Content.Entries.Schema

  @spec populate(
          Entry.t() | [Entry.t()],
          Okovita.Content.Model.t(),
          String.t(),
          keyword()
        ) :: Entry.t() | [Entry.t()]
  @doc """
  Populates fields for a single entry or list of entries.
  Replaces UUID references with full structs by retrieving from corresponding tables.
  """
  def populate(entries, model, prefix, opts \\ [])

  def populate(entries, model, prefix, opts) when is_list(entries) do
    keys_by_target = group_keys_by_target(model.schema_definition)

    if Enum.empty?(keys_by_target) do
      entries
    else
      entities_map = fetch_all_entities(entries, keys_by_target, prefix)
      all_keys = Enum.flat_map(keys_by_target, fn {_, keys} -> keys end)

      Enum.map(entries, &do_populate(&1, all_keys, entities_map, opts))
    end
  end

  def populate(%Entry{} = entry, model, prefix, opts) do
    populate([entry], model, prefix, opts) |> hd()
  end

  # ── Grouping & Fetching ──────────────────────────────────────────

  @spec group_keys_by_target(map()) :: %{optional(atom()) => [{String.t(), String.t()}]}
  defp group_keys_by_target(schema_definition) do
    for {key, attrs} <- schema_definition,
        type = attrs["field_type"],
        target = Okovita.FieldTypes.Registry.population_target(type),
        not is_nil(target),
        reduce: %{} do
      acc -> Map.update(acc, target, [{key, type}], &[{key, type} | &1])
    end
  end

  @spec fetch_all_entities([Entry.t()], map(), String.t()) :: map()
  defp fetch_all_entities(entries, keys_by_target, prefix) do
    Enum.reduce(keys_by_target, %{}, fn {target, keys}, acc ->
      ids =
        entries
        |> Schema.collect_ids_for_keys(keys)
        |> Enum.uniq()

      Map.merge(acc, fetch_by_target(target, ids, prefix))
    end)
  end

  @spec fetch_by_target(atom(), [String.t()], String.t()) :: map()
  defp fetch_by_target(_target, [], _prefix), do: %{}

  defp fetch_by_target(:entry, ids, prefix) do
    Entries.get_entries_by_ids(ids, prefix)
  end

  defp fetch_by_target(:media, ids, prefix) do
    Okovita.Content.get_media_by_ids(ids, prefix)
    |> Map.new(&{&1.id, &1})
  end

  defp fetch_by_target(_, _ids, _prefix), do: %{}

  # ── Private helpers ───────────────────────────────────────────────

  @spec do_populate(Entry.t(), [{String.t(), String.t()}], map(), keyword()) :: Entry.t()
  defp do_populate(entry, keys, entities_map, opts) do
    populate = Keyword.get(opts, :populate, [])

    new_data =
      Enum.reduce(keys, entry.data || %{}, fn {key, type}, acc_data ->
        if should_populate?(key, populate) do
          populated_val =
            Okovita.FieldTypes.Registry.populate(type, Map.get(acc_data, key), entities_map, opts)

          Map.put(acc_data, key, populated_val)
        else
          acc_data
        end
      end)

    %{entry | data: new_data}
  end

  @spec should_populate?(String.t(), :all | [String.t()] | any()) :: boolean()
  defp should_populate?(_key, :all), do: true
  defp should_populate?(_key, []), do: false
  defp should_populate?(key, fields) when is_list(fields), do: key in fields
  defp should_populate?(_key, _), do: false
end
