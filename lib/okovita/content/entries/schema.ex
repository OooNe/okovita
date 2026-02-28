defmodule Okovita.Content.Entries.Schema do
  @moduledoc """
  Schema introspection helpers for content entries.
  """

  alias Okovita.FieldTypes.Registry

  @spec get_relation_keys_for_parent(map(), String.t()) :: [{String.t(), String.t()}]
  @doc "Gets relation keys that point to a specific parent model."
  def get_relation_keys_for_parent(child_model, parent_model_slug) do
    child_model.schema_definition
    |> Enum.filter(fn {_key, attrs} ->
      Registry.population_target(attrs["field_type"]) == :entry and
        attrs["target_model"] == parent_model_slug
    end)
    |> Enum.map(fn {key, attrs} -> {key, attrs["field_type"]} end)
  end

  @spec get_relation_keys(map()) :: [{String.t(), String.t()}]
  @doc "Gets all relation keys from a model."
  def get_relation_keys(model) do
    model.schema_definition
    |> Enum.filter(fn {_key, attrs} ->
      Registry.population_target(attrs["field_type"]) == :entry
    end)
    |> Enum.map(fn {key, attrs} -> {key, attrs["field_type"]} end)
  end

  @spec get_media_keys(map()) :: [{String.t(), String.t()}]
  @doc "Gets all media keys from a model."
  def get_media_keys(model) do
    model.schema_definition
    |> Enum.filter(fn {_key, attrs} ->
      Registry.targets_media?(attrs["field_type"])
    end)
    |> Enum.map(fn {key, attrs} -> {key, attrs["field_type"]} end)
  end

  @spec collect_ids_for_keys([map()], [{String.t(), String.t()}]) :: [String.t()]
  @doc "Collects UUIDs from a list of entries based on the provided keys and their field types."
  def collect_ids_for_keys(entries, keys) do
    for entry <- entries,
        {key, type} <- keys,
        id <- Registry.extract_references(type, Map.get(entry.data || %{}, key)),
        do: id
  end
end
