defmodule Okovita.Backup.Importer do
  @moduledoc """
  Imports tenant data from JSON backup format.

  Performs a complete replacement of tenant data - deletes all existing
  models, entries, and media, then imports from backup.

  All operations are atomic via Ecto.Multi.
  """

  require Logger

  alias Ecto.Multi
  alias Okovita.Repo
  alias Okovita.Tenants
  alias Okovita.Content.{Model, Entry, Media}
  alias Okovita.Backup.{Format, RelationResolver}

  import Ecto.Query

  @doc """
  Imports tenant data from a backup file.

  ## Options
    * `:dry_run` - Validate only, don't execute (default: false)

  Returns `{:ok, summary}` on success or `{:error, reason}` on failure.
  """
  @spec import_tenant(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def import_tenant(file_path, tenant_slug, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)

    with {:ok, backup_data} <- read_and_validate_backup(file_path),
         {:ok, tenant} <- get_tenant_by_slug(tenant_slug),
         prefix = Tenants.tenant_prefix(tenant) do
      if dry_run do
        Logger.info("Dry run mode - validation successful, no changes made")
        {:ok, build_summary(backup_data, dry_run: true)}
      else
        execute_import(backup_data, prefix)
      end
    end
  end

  # Private functions

  defp read_and_validate_backup(file_path) do
    with {:ok, json} <- read_file(file_path),
         {:ok, data} <- decode_json(json),
         {:ok, validated_data} <- Format.validate(data) do
      {:ok, validated_data}
    end
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, {:file_read, reason}}
    end
  end

  defp decode_json(json) do
    case Jason.decode(json) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, {:json_decode, reason}}
    end
  end

  defp get_tenant_by_slug(slug) do
    case Tenants.get_tenant_by_slug(slug) do
      nil -> {:error, :tenant_not_found}
      tenant -> {:ok, tenant}
    end
  end

  defp execute_import(backup_data, prefix) do
    Logger.info("Starting import transaction...")

    result =
      Multi.new()
      |> delete_existing_data(prefix)
      |> import_models(backup_data["models"], prefix)
      |> import_media(backup_data["media"], prefix)
      |> import_entries(backup_data["entries"], prefix)
      |> Repo.transaction()

    case result do
      {:ok, changes} ->
        summary = %{
          models_count: map_size(changes.model_map),
          media_count: map_size(changes.media_map),
          entries_count: changes.entries_count
        }

        Logger.info("Import completed successfully")
        {:ok, summary}

      {:error, step, reason, _changes} ->
        Logger.error("Import failed at step #{step}: #{inspect(reason)}")
        {:error, {step, reason}}
    end
  end

  defp delete_existing_data(multi, prefix) do
    multi
    |> Multi.delete_all(:delete_entries, from(e in Entry), prefix: prefix)
    |> Multi.delete_all(:delete_models, from(m in Model), prefix: prefix)
    |> Multi.delete_all(:delete_media, from(m in Media), prefix: prefix)
  end

  defp import_models(multi, models_data, prefix) do
    Multi.run(multi, :model_map, fn _repo, _changes ->
      # Model uses :utc_datetime (has @timestamps_opts)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Generate new UUIDs for models
      models_with_ids =
        Enum.map(models_data, fn model_data ->
          new_id = Ecto.UUID.generate()

          %{
            id: new_id,
            slug: model_data["slug"],
            name: model_data["name"],
            publishable: model_data["publishable"],
            is_component: model_data["is_component"],
            slug_field: model_data["slug_field"],
            schema_definition: model_data["schema_definition"],
            inserted_at: now,
            updated_at: now
          }
        end)

      # Batch insert
      case Repo.insert_all(Model, models_with_ids, prefix: prefix) do
        {count, _} when count > 0 ->
          # Build mapping: slug → UUID
          model_map =
            models_with_ids
            |> Enum.map(fn m -> {m.slug, m.id} end)
            |> Map.new()

          Logger.info("Imported #{count} models")
          {:ok, model_map}

        {0, _} ->
          Logger.info("No models to import")
          {:ok, %{}}
      end
    end)
  end

  defp import_media(multi, media_data, prefix) do
    Multi.run(multi, :media_map, fn _repo, _changes ->
      if Enum.empty?(media_data) do
        Logger.info("No media to import")
        {:ok, %{}}
      else
        # Media uses :naive_datetime (default timestamps())
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        # Generate new UUIDs for media, map old_id → new_id
        media_with_ids =
          Enum.map(media_data, fn media ->
            old_id = media["id"]
            new_id = Ecto.UUID.generate()

            {old_id,
             %{
               id: new_id,
               file_name: media["file_name"],
               url: media["url"],
               mime_type: media["mime_type"],
               size: media["size"],
               width: media["width"],
               height: media["height"],
               inserted_at: now,
               updated_at: now
             }}
          end)

        media_records = Enum.map(media_with_ids, fn {_old_id, record} -> record end)

        case Repo.insert_all(Media, media_records, prefix: prefix) do
          {count, _} when count > 0 ->
            # Build mapping: old_id → new_id
            media_map =
              media_with_ids
              |> Enum.map(fn {old_id, record} -> {old_id, record.id} end)
              |> Map.new()

            Logger.info("Imported #{count} media items")
            {:ok, media_map}

          {0, _} ->
            {:ok, %{}}
        end
      end
    end)
  end

  defp import_entries(multi, entries_data, prefix) do
    Multi.run(multi, :entries_count, fn _repo, %{model_map: model_map, media_map: media_map} ->
      if Enum.empty?(entries_data) do
        Logger.info("No entries to import")
        {:ok, 0}
      else
        # Entry uses :utc_datetime (has @timestamps_opts)
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        # Pre-assign UUIDs so we can build an in-memory map for relation resolution
        entries_with_new_ids =
          Enum.map(entries_data, fn entry_data ->
            {entry_data, Ecto.UUID.generate()}
          end)

        # Build {model_slug, slug} → new_uuid map for relation normalization
        entry_map =
          entries_with_new_ids
          |> Enum.map(fn {entry_data, new_id} ->
            {{entry_data["model_slug"], entry_data["slug"]}, new_id}
          end)
          |> Map.new()

        entries_with_ids =
          Enum.map(entries_with_new_ids, fn {entry_data, new_id} ->
            model_slug = entry_data["model_slug"]

            case Map.get(model_map, model_slug) do
              nil ->
                Logger.warning("Skipping entry with unknown model: #{model_slug}")
                nil

              model_id ->
                model = Repo.get(Model, model_id, prefix: prefix)

                normalized_data =
                  RelationResolver.normalize_relations(
                    entry_data["data"],
                    model.schema_definition,
                    entry_map
                  )

                remapped_data = remap_media_ids(normalized_data, media_map)

                %{
                  id: new_id,
                  model_id: model_id,
                  slug: entry_data["slug"],
                  data: remapped_data,
                  published_at: parse_datetime(entry_data["published_at"]),
                  inserted_at: now,
                  updated_at: now
                }
            end
          end)
          |> Enum.reject(&is_nil/1)

        case Repo.insert_all(Entry, entries_with_ids, prefix: prefix) do
          {count, _} when count > 0 ->
            Logger.info("Imported #{count} entries")
            {:ok, count}

          {0, _} ->
            {:ok, 0}
        end
      end
    end)
  end

  # Remap media UUIDs in entry data
  defp remap_media_ids(data, media_map) when is_map(data) do
    Enum.reduce(data, %{}, fn {key, value}, acc ->
      remapped_value =
        cond do
          # Single media ID (image field)
          is_binary(value) && Map.has_key?(media_map, value) ->
            media_map[value]

          # List of media IDs (image_gallery field)
          is_list(value) ->
            Enum.map(value, fn
              id when is_binary(id) -> Map.get(media_map, id, id)
              other -> other
            end)

          # Nested map (might contain media IDs)
          is_map(value) ->
            remap_media_ids(value, media_map)

          # Pass through
          true ->
            value
        end

      Map.put(acc, key, remapped_value)
    end)
  end

  defp remap_media_ids(data, _media_map), do: data

  defp parse_datetime(nil), do: nil

  defp parse_datetime(iso8601) when is_binary(iso8601) do
    case DateTime.from_iso8601(iso8601) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp build_summary(backup_data, opts) do
    %{
      models_count: length(backup_data["models"]),
      entries_count: length(backup_data["entries"]),
      media_count: length(backup_data["media"]),
      dry_run: Keyword.get(opts, :dry_run, false)
    }
  end
end
