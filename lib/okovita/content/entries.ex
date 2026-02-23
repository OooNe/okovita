defmodule Okovita.Content.Entries do
  @moduledoc """
  Sub-context for managing content entries, including integration with
  sync pipelines and dynamic changeset validation.
  """

  alias Ecto.Multi
  alias Okovita.Repo
  alias Okovita.Content.{Entry, DynamicChangeset, Models}
  alias Okovita.Timeline.Auditor

  import Ecto.Query

  @doc """
  Creates an entry for a content model.

  Validates data against the model's schema_definition using DynamicChangeset,
  applies sync pipelines, and records a timeline entry.
  """
  @spec create_entry(binary(), map(), String.t(), binary() | nil) ::
          {:ok, Entry.t()} | {:error, any()}
  def create_entry(model_id, attrs, prefix, actor_id \\ nil) do
    case Models.get_model(model_id, prefix) do
      nil ->
        {:error, :model_not_found}

      model ->
        data = Map.get(attrs, :data) || Map.get(attrs, "data", %{})
        slug = Map.get(attrs, :slug) || Map.get(attrs, "slug")

        # Validate data against the model's schema_definition
        case DynamicChangeset.build(model.schema_definition, data) do
          {:ok, validated_data} ->
            # Apply sync pipelines to validated data
            processed_data = apply_sync_pipelines(validated_data)
            string_data = to_string_keyed_map(processed_data)

            entry_attrs = %{
              slug: slug,
              model_id: model_id,
              data: string_data
            }

            result =
              Multi.new()
              |> Multi.insert(:entry, Entry.changeset(%Entry{}, entry_attrs), prefix: prefix)
              |> Auditor.insert_audit(
                "entry",
                "create",
                actor_id,
                fn %{entry: entry} ->
                  {
                    entry.id,
                    nil,
                    %{slug: entry.slug, data: entry.data}
                  }
                end,
                prefix: prefix
              )
              |> Repo.transaction()

            case result do
              {:ok, %{entry: entry}} -> {:ok, entry}
              {:error, :entry, changeset, _} -> {:error, changeset}
            end

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc """
  Updates an entry's data and/or slug.

  Re-validates data against the model's schema_definition and applies sync pipelines.
  """
  @spec update_entry(binary(), binary(), map(), String.t(), binary() | nil) ::
          {:ok, Entry.t()} | {:error, any()}
  def update_entry(entry_id, model_id, attrs, prefix, actor_id \\ nil) do
    case {get_entry(entry_id, prefix), Models.get_model(model_id, prefix)} do
      {nil, _} ->
        {:error, :not_found}

      {_, nil} ->
        {:error, :model_not_found}

      {entry, model} ->
        data = Map.get(attrs, :data) || Map.get(attrs, "data")
        slug = Map.get(attrs, :slug) || Map.get(attrs, "slug")

        # Validate new data if provided
        new_data =
          if data do
            case DynamicChangeset.build(model.schema_definition, data) do
              {:ok, validated_data} ->
                {:ok, apply_sync_pipelines(validated_data)}

              {:error, _} = err ->
                err
            end
          else
            {:ok, nil}
          end

        case new_data do
          {:ok, processed_data} ->
            before_data = %{slug: entry.slug, data: entry.data}

            update_attrs =
              %{}
              |> maybe_put(:slug, slug)
              |> maybe_put(:data, if(processed_data, do: to_string_keyed_map(processed_data)))

            result =
              Multi.new()
              |> Multi.update(:entry, Entry.update_changeset(entry, update_attrs), prefix: prefix)
              |> Auditor.insert_audit(
                "entry",
                "update",
                actor_id,
                fn %{entry: updated_entry} ->
                  {
                    entry.id,
                    before_data,
                    %{slug: updated_entry.slug, data: updated_entry.data}
                  }
                end,
                prefix: prefix
              )
              |> Repo.transaction()

            case result do
              {:ok, %{entry: entry}} -> {:ok, entry}
              {:error, :entry, changeset, _} -> {:error, changeset}
            end

          {:error, _} = err ->
            err
        end
    end
  end

  @doc "Deletes an entry and records a timeline event."
  @spec delete_entry(binary(), String.t(), binary() | nil) ::
          {:ok, Entry.t()} | {:error, any()}
  def delete_entry(entry_id, prefix, actor_id \\ nil) do
    case get_entry(entry_id, prefix) do
      nil ->
        {:error, :not_found}

      entry ->
        before_data = %{slug: entry.slug, data: entry.data}

        result =
          Multi.new()
          |> Multi.delete(:entry, entry, prefix: prefix)
          |> Auditor.insert_audit(
            "entry",
            "delete",
            actor_id,
            fn _changes ->
              {entry.id, before_data, nil}
            end,
            prefix: prefix
          )
          |> Repo.transaction()

        case result do
          {:ok, %{entry: entry}} -> {:ok, entry}
          {:error, :entry, changeset, _} -> {:error, changeset}
        end
    end
  end

  @doc "Gets an entry by ID."
  def get_entry(id, prefix) do
    Repo.get(Entry, id, prefix: prefix)
  end

  @doc "Lists entries for a model."
  def list_entries(model_id, prefix) do
    from(e in Entry,
      where: e.model_id == ^model_id,
      order_by: [desc: e.inserted_at]
    )
    |> Repo.all(prefix: prefix)
  end

  @doc """
  Populates relation fields for a single entry or list of entries.
  Replaces UUID strings with their corresponding full JSON entry objects representations.
  """
  def populate_relations(entries, model, prefix, opts \\ [])

  def populate_relations(entries, model, prefix, opts) when is_list(entries) do
    relation_keys = get_relation_keys(model)

    if Enum.empty?(relation_keys) do
      entries
    else
      Enum.map(entries, &do_populate(&1, relation_keys, prefix, opts))
    end
  end

  def populate_relations(%Entry{} = entry, model, prefix, opts) do
    relation_keys = get_relation_keys(model)

    if Enum.empty?(relation_keys) do
      entry
    else
      do_populate(entry, relation_keys, prefix, opts)
    end
  end

  @doc """
  Populates media fields (`image` and `image_gallery`) for a single entry or list of entries.
  Replaces `media_id` references with full media objects containing `url` and other metadata.
  """
  def populate_media(entries, model, prefix)

  def populate_media(entries, model, prefix) when is_list(entries) do
    media_keys = get_media_keys(model)

    if Enum.empty?(media_keys) do
      entries
    else
      # Collect all media IDs across all entries
      all_media_ids =
        entries
        |> collect_media_ids_for_keys(media_keys)
        |> Enum.uniq()

      # Fetch all media in one batch
      media_map =
        Okovita.Content.get_media_by_ids(all_media_ids, prefix)
        |> Enum.map(&{&1.id, &1})
        |> Enum.into(%{})

      Enum.map(entries, &do_populate_media(&1, media_keys, media_map))
    end
  end

  def populate_media(%Entry{} = entry, model, prefix) do
    media_keys = get_media_keys(model)

    if Enum.empty?(media_keys) do
      entry
    else
      media_ids = collect_media_ids_for_keys([entry], media_keys)

      media_map =
        Okovita.Content.get_media_by_ids(media_ids, prefix)
        |> Enum.map(&{&1.id, &1})
        |> Enum.into(%{})

      do_populate_media(entry, media_keys, media_map)
    end
  end

  # ── Private helpers ───────────────────────────────────────────────

  defp get_relation_keys(model) do
    model.schema_definition
    |> Enum.filter(fn {_key, attrs} ->
      attrs["field_type"] in ["relation", "relation_many"]
    end)
    |> Enum.map(fn {key, attrs} -> {key, attrs["field_type"]} end)
  end

  defp do_populate(entry, relation_keys, prefix, opts) do
    with_metadata = Keyword.get(opts, :with_metadata, true)

    new_data =
      Enum.reduce(relation_keys, entry.data || %{}, fn
        {key, "relation"}, acc_data ->
          case Map.get(acc_data, key) do
            id when is_binary(id) and id != "" ->
              case get_entry(id, prefix) do
                nil -> acc_data
                target_entry -> Map.put(acc_data, key, entry_json(target_entry, with_metadata))
              end

            _ ->
              acc_data
          end

        {key, "relation_many"}, acc_data ->
          ids = Map.get(acc_data, key, [])

          case ids do
            ids when is_list(ids) and ids != [] ->
              # Batch fetch — one query for uids in this field
              valid_ids = Enum.filter(ids, &is_uuid?/1)

              entries_map =
                from(e in Entry, where: e.id in ^valid_ids)
                |> Repo.all(prefix: prefix)
                |> Enum.map(&{&1.id, &1})
                |> Enum.into(%{})

              populated =
                valid_ids
                |> Enum.map(&Map.get(entries_map, &1))
                |> Enum.reject(&is_nil/1)
                |> Enum.map(&entry_json(&1, with_metadata))

              Map.put(acc_data, key, populated)

            _ ->
              acc_data
          end
      end)

    %{entry | data: new_data}
  end

  defp get_media_keys(model) do
    model.schema_definition
    |> Enum.filter(fn {_key, attrs} -> attrs["field_type"] in ["image", "image_gallery"] end)
    |> Enum.map(fn {key, attrs} -> {key, attrs["field_type"]} end)
  end

  defp collect_media_ids_for_keys(entries, media_keys) do
    Enum.flat_map(entries, fn entry ->
      Enum.flat_map(media_keys, fn
        {key, "image"} ->
          case Map.get(entry.data || %{}, key) do
            id when is_binary(id) ->
              if is_uuid?(id), do: [id], else: []

            _ ->
              []
          end

        {key, "image_gallery"} ->
          gallery = Map.get(entry.data || %{}, key, [])

          Enum.flat_map(gallery, fn
            %{"media_id" => id} when is_binary(id) ->
              if is_uuid?(id), do: [id], else: []

            _ ->
              []
          end)
      end)
    end)
  end

  defp do_populate_media(entry, media_keys, media_map) do
    new_data =
      Enum.reduce(media_keys, entry.data || %{}, fn
        {key, "image"}, acc_data ->
          case Map.get(acc_data, key) do
            id when is_binary(id) ->
              media = if is_uuid?(id), do: media_map[id]

              if media do
                Map.put(acc_data, key, media_json(media))
              else
                acc_data
              end

            _ ->
              acc_data
          end

        {key, "image_gallery"}, acc_data ->
          gallery = Map.get(acc_data, key, [])

          populated_gallery =
            Enum.map(gallery, fn
              %{"media_id" => id} = item when is_binary(id) ->
                media = if is_uuid?(id), do: media_map[id]

                if media do
                  Map.merge(item, media_json(media))
                else
                  item
                end

              item ->
                item
            end)

          Map.put(acc_data, key, populated_gallery)
      end)

    %{entry | data: new_data}
  end

  defp is_uuid?(id) when is_binary(id) do
    match?({:ok, _}, Ecto.UUID.cast(id))
  end

  defp is_uuid?(_), do: false

  defp media_json(media) do
    %{
      "id" => media.id,
      "url" => media.url,
      "file_name" => media.file_name,
      "mime_type" => media.mime_type
    }
  end

  defp entry_json(entry, with_metadata) do
    data = Map.put(entry.data || %{}, "id", entry.id)

    if with_metadata do
      %{
        metadata: %{
          slug: entry.slug,
          model_id: entry.model_id,
          inserted_at: entry.inserted_at,
          updated_at: entry.updated_at
        },
        data: data
      }
    else
      data
    end
  end

  defp apply_sync_pipelines(data) when is_map(data) do
    pipelines = Application.get_env(:okovita, :sync_pipelines, [])

    Enum.reduce(pipelines, data, fn {_name, module}, acc ->
      Enum.into(acc, %{}, fn {key, value} ->
        case module.apply(value, %{}) do
          {:ok, new_value} -> {key, new_value}
          {:error, _} -> {key, value}
        end
      end)
    end)
  end

  defp to_string_keyed_map(data) when is_map(data) do
    Enum.into(data, %{}, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
