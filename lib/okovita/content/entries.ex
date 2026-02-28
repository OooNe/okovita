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
        slug = Map.get(attrs, :slug) || Map.get(attrs, "slug")

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

        new_data =
          if data do
            DynamicChangeset.build(model.schema_definition, data)
          else
            {:ok, nil}
          end

        case new_data do
          {:ok, validated_data} ->
            before_data = %{slug: entry.slug, data: entry.data}

            update_attrs =
              %{}
              |> maybe_put(:slug, slug)
              |> maybe_put(:data, if(validated_data, do: to_string_keyed_map(validated_data)))

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
    from(e in Entry,
      where: e.model_id == ^model_id,
      order_by: [desc: e.inserted_at]
    )
    |> Repo.all(prefix: prefix)
  end

  defdelegate list_entries_by_parent(parent_id, parent_model_slug, child_model_slug, prefix),
    to: Okovita.Content.Entries.Queries

  defdelegate populate(entries, model, prefix, opts \\ []),
    to: Okovita.Content.Entries.Population
end
