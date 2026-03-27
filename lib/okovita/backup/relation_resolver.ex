defmodule Okovita.Backup.RelationResolver do
  @moduledoc """
  Converts between UUID-based and slug-based relations for backup/restore.

  For export (denormalize):
    UUID → %{"model_slug" => "...", "slug" => "..."}

  For import (normalize):
    %{"model_slug" => "...", "slug" => "..."} → UUID
  """

  require Logger

  alias Okovita.Content

  @doc """
  Denormalizes entry data for backup (UUIDs → slug pairs).

  Iterates through schema_definition and converts relation/relation_many
  field values from UUIDs to {model_slug, slug} pairs.
  """
  @spec denormalize_relations(map(), map(), String.t()) :: map()
  def denormalize_relations(data, schema_definition, prefix) do
    Enum.reduce(schema_definition, data, fn {key, attrs}, acc ->
      field_type = attrs["field_type"]
      value = Map.get(acc, key)

      case denormalize_field(value, field_type, prefix) do
        {:ok, denormalized_value} ->
          Map.put(acc, key, denormalized_value)

        {:error, _reason} ->
          # Keep original value if denormalization fails
          acc
      end
    end)
  end

  @doc """
  Normalizes entry data for import (slug pairs → UUIDs).

  Converts {model_slug, slug} pairs back to UUIDs using the entry_map
  built in-memory during import (before DB insert).
  """
  @spec normalize_relations(map(), map(), map()) :: map()
  def normalize_relations(data, schema_definition, entry_map) do
    Enum.reduce(schema_definition, data, fn {key, attrs}, acc ->
      field_type = attrs["field_type"]
      value = Map.get(acc, key)

      case normalize_field(value, field_type, entry_map) do
        {:ok, normalized_value} ->
          Map.put(acc, key, normalized_value)

        {:error, reason} ->
          Logger.warning(
            "Failed to normalize field '#{key}': #{inspect(reason)}, clearing field"
          )

          Map.put(acc, key, nil)
      end
    end)
  end

  # Denormalization (export) - UUID → slug pair

  defp denormalize_field(uuid, "relation", prefix) when is_binary(uuid) do
    case get_entry_with_model(uuid, prefix) do
      {:ok, entry, model} ->
        {:ok, %{"model_slug" => model.slug, "slug" => entry.slug}}

      {:error, _} = error ->
        Logger.warning("Failed to denormalize relation #{uuid}: orphaned reference")
        error
    end
  end

  defp denormalize_field(uuids, "relation_many", prefix) when is_list(uuids) do
    results =
      Enum.map(uuids, fn uuid ->
        case get_entry_with_model(uuid, prefix) do
          {:ok, entry, model} ->
            {:ok, %{"model_slug" => model.slug, "slug" => entry.slug}}

          {:error, _} ->
            Logger.warning("Failed to denormalize relation #{uuid}: orphaned reference")
            {:error, :not_found}
        end
      end)

    # Filter out errors and collect successful results
    denormalized =
      results
      |> Enum.filter(fn
        {:ok, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {:ok, value} -> value end)

    {:ok, denormalized}
  end

  defp denormalize_field(value, _field_type, _prefix) do
    # Not a relation field or nil value - pass through
    {:ok, value}
  end

  # Normalization (import) - slug pair → UUID

  defp normalize_field(%{"model_slug" => model_slug, "slug" => slug}, "relation", entry_map) do
    case Map.get(entry_map, {model_slug, slug}) do
      nil -> {:error, {:entry_not_found, model_slug, slug}}
      uuid -> {:ok, uuid}
    end
  end

  defp normalize_field(slug_pairs, "relation_many", entry_map) when is_list(slug_pairs) do
    normalized =
      Enum.flat_map(slug_pairs, fn %{"model_slug" => model_slug, "slug" => slug} ->
        case Map.get(entry_map, {model_slug, slug}) do
          nil ->
            Logger.warning("Entry not found: #{model_slug}/#{slug}, skipping")
            []

          uuid ->
            [uuid]
        end
      end)

    {:ok, normalized}
  end

  defp normalize_field(value, _field_type, _entry_map) do
    {:ok, value}
  end

  # Helper functions (export only)

  defp get_entry_with_model(entry_id, prefix) do
    case Content.get_entry(entry_id, prefix) do
      nil ->
        {:error, :not_found}

      entry ->
        case Content.get_model(entry.model_id, prefix) do
          nil ->
            {:error, :model_not_found}

          model ->
            {:ok, entry, model}
        end
    end
  end
end
