defmodule Okovita.Content.Entries do
  @moduledoc """
  Sub-context for managing content entries, including integration with
  sync pipelines and dynamic changeset validation.
  """

  alias Ecto.Multi
  alias Okovita.Repo
  alias Okovita.Content.{Entry, DynamicChangeset, Models}
  alias Okovita.Timeline
  alias Okovita.Content.SlugGenerator

  import Ecto.Query
  import Okovita.Content.Entries.Utils

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

        slug = SlugGenerator.build(attrs, data, model, prefix)

        # Validate data against the model's schema_definition
        case DynamicChangeset.build(model.schema_definition, data) do
        {:ok, validated_data} ->
            string_data = to_string_keyed_map(validated_data)

            entry_attrs = %{
              slug: slug,
              model_id: model_id,
              data: string_data
            }

            result =
              Multi.new()
              |> Multi.insert(:entry, Entry.changeset(%Entry{}, entry_attrs), prefix: prefix)
              |> Timeline.insert_audit(
                "entry",
                "create",
                actor_id,
                fn %{entry: entry} ->
                  populated = populate(entry, model, prefix, populate: :all)
                  {
                    entry.id,
                    nil,
                    %{
                      slug: entry.slug,
                      raw_data: entry.data,
                      data: populated.data,
                      published_at: entry.published_at
                    }
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

        new_data =
          if data do
            DynamicChangeset.build(model.schema_definition, data)
          else
            {:ok, nil}
          end

        case new_data do
          {:ok, validated_data} ->
            populated_before = populate(entry, model, prefix, populate: :all)
            before_data = %{
              slug: entry.slug,
              raw_data: entry.data,
              data: populated_before.data,
              published_at: entry.published_at
            }

            update_attrs =
              %{}
              |> maybe_put(:slug, slug)
              |> maybe_put(:data, if(validated_data, do: to_string_keyed_map(validated_data)))

            result =
              Multi.new()
              |> Multi.update(:entry, Entry.update_changeset(entry, update_attrs), prefix: prefix)
              |> Timeline.insert_audit(
                "entry",
                "update",
                actor_id,
                fn %{entry: updated_entry} ->
                  populated_after = populate(updated_entry, model, prefix, populate: :all)
                  {
                    entry.id,
                    before_data,
                    %{
                      slug: updated_entry.slug,
                      raw_data: updated_entry.data,
                      data: populated_after.data,
                      published_at: updated_entry.published_at
                    }
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

  @doc """
  Restores an entry's data and slug to a previous timeline record state.
  """
  @spec restore_entry(binary(), binary(), String.t(), binary() | nil) ::
          {:ok, Entry.t()} | {:error, any()}
  def restore_entry(entry_id, record_id, prefix, actor_id \\ nil) do
    case {get_entry(entry_id, prefix), Repo.get(Okovita.Timeline.Record, record_id, prefix: prefix)} do
      {nil, _} ->
        {:error, :not_found}

      {_, nil} ->
        {:error, :record_not_found}

      {entry, record} ->
        if record.entity_id != entry_id or record.entity_type != "entry" or is_nil(record.after) do
          {:error, :invalid_record}
        else
          # Fallback for older records which did not have raw_data
          raw_data = Map.get(record.after, "raw_data") || Map.get(record.after, "data") || %{}
          slug = Map.get(record.after, "slug") || entry.slug

          new_data = DynamicChangeset.build(entry.model.schema_definition, raw_data)

          case new_data do
            {:ok, validated_data} ->
              populated_before = populate(entry, entry.model, prefix, populate: :all)
              before_data = %{
                slug: entry.slug,
                raw_data: entry.data,
                data: populated_before.data,
                published_at: entry.published_at
              }

              update_attrs =
                %{}
                |> maybe_put(:slug, slug)
                |> maybe_put(:data, to_string_keyed_map(validated_data))

              result =
                Multi.new()
                |> Multi.update(:entry, Entry.update_changeset(entry, update_attrs), prefix: prefix)
                |> Timeline.insert_audit(
                  "entry",
                  "restore",
                  actor_id,
                  fn %{entry: updated_entry} ->
                    populated_after = populate(updated_entry, entry.model, prefix, populate: :all)
                    {
                      entry.id,
                      before_data,
                      %{
                        slug: updated_entry.slug,
                        raw_data: updated_entry.data,
                        data: populated_after.data,
                        published_at: updated_entry.published_at
                      }
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
  end

  @doc "Deletes an entry and records a timeline event."
  @spec delete_entry(binary(), String.t(), binary() | nil) ::
          {:ok, Entry.t()} | {:error, any()}
  def delete_entry(entry_id, prefix, actor_id \\ nil) do
    case get_entry(entry_id, prefix) do
      nil ->
        {:error, :not_found}

      entry ->
        populated_before = populate(entry, entry.model, prefix, populate: :all)
        before_data = %{
          slug: entry.slug,
          raw_data: entry.data,
          data: populated_before.data,
          published_at: entry.published_at
        }

        result =
          Multi.new()
          |> Multi.delete(:entry, entry, prefix: prefix)
          |> Timeline.insert_audit(
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
    Repo.get(Entry, id, prefix: prefix) |> Repo.preload(:model, prefix: prefix)
  end

  @doc "Gets multiple entries by their IDs."
  def get_entries_by_ids(ids, prefix) do
    from(e in Entry, where: e.id in ^ids, preload: [:model])
    |> Repo.all(prefix: prefix)
    |> Enum.map(&{&1.id, &1})
    |> Enum.into(%{})
  end

  @doc "Lists entries for a model."
  def list_entries(model_id, prefix) do
    entries =
      from(e in Entry,
        where: e.model_id == ^model_id,
        order_by: [desc: e.inserted_at]
      )
      |> Repo.all(prefix: prefix)

    if entries == [] do
      []
    else
      entry_ids = Enum.map(entries, & &1.id)

      latest_records =
        from(r in Okovita.Timeline.Record,
          where: r.entity_type == "entry" and r.entity_id in ^entry_ids,
          distinct: r.entity_id,
          order_by: [desc: r.inserted_at],
          select: {r.entity_id, r.actor_id}
        )
        |> Repo.all(prefix: prefix)

      actor_ids =
        latest_records
        |> Enum.map(fn {_, actor_id} -> actor_id end)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      admins_map =
        if actor_ids == [] do
          %{}
        else
          from(a in Okovita.Auth.Admin, where: a.id in ^actor_ids, select: {a.id, a.email})
          |> Repo.all()
          |> Enum.into(%{})
        end

      editor_map =
        Enum.into(latest_records, %{}, fn {entity_id, actor_id} ->
          {entity_id, Map.get(admins_map, actor_id)}
        end)

      Enum.map(entries, fn entry ->
        %{entry | last_editor: Map.get(editor_map, entry.id)}
      end)
    end
  end

  defdelegate list_entries_by_parent(parent_id, parent_model_slug, child_model_slug, prefix),
    to: Okovita.Content.Entries.Queries

  defdelegate populate(entries, model, prefix, opts \\ []),
    to: Okovita.Content.Entries.Population

  @doc "Publishes an entry by setting its published_at timestamp."
  @spec publish_entry(binary(), String.t(), binary() | nil) ::
          {:ok, Entry.t()} | {:error, any()}
  def publish_entry(entry_id, prefix, actor_id \\ nil) do
    case get_entry(entry_id, prefix) do
      nil ->
        {:error, :not_found}

      entry ->
        result =
          Multi.new()
          |> Multi.update(:entry, Entry.publish_changeset(entry), prefix: prefix)
          |> Timeline.insert_audit(
            "entry",
            "publish",
            actor_id,
            fn %{entry: updated} ->
              populated = populate(updated, entry.model, prefix, populate: :all)
              data_map = %{
                slug: updated.slug,
                raw_data: updated.data,
                data: populated.data
              }

              {entry.id,
               Map.put(data_map, :published_at, entry.published_at),
               Map.put(data_map, :published_at, updated.published_at)}
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

  @doc "Unpublishes an entry by clearing its published_at timestamp."
  @spec unpublish_entry(binary(), String.t(), binary() | nil) ::
          {:ok, Entry.t()} | {:error, any()}
  def unpublish_entry(entry_id, prefix, actor_id \\ nil) do
    case get_entry(entry_id, prefix) do
      nil ->
        {:error, :not_found}

      entry ->
        result =
          Multi.new()
          |> Multi.update(:entry, Entry.unpublish_changeset(entry), prefix: prefix)
          |> Timeline.insert_audit(
            "entry",
            "unpublish",
            actor_id,
            fn %{entry: updated} ->
              populated = populate(updated, entry.model, prefix, populate: :all)
              data_map = %{
                slug: updated.slug,
                raw_data: updated.data,
                data: populated.data
              }

              {entry.id,
               Map.put(data_map, :published_at, entry.published_at),
               Map.put(data_map, :published_at, updated.published_at)}
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

  @doc "Lists only published entries for a model."
  def list_published_entries(model_id, prefix) do
    from(e in Entry,
      where: e.model_id == ^model_id and not is_nil(e.published_at),
      order_by: [desc: e.inserted_at]
    )
    |> Repo.all(prefix: prefix)
  end

  # --- Prywatne
end
