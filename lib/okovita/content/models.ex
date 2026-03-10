defmodule Okovita.Content.Models do
  @moduledoc """
  Sub-context for managing content models within a tenant schema.
  """

  alias Ecto.Multi
  alias Okovita.Repo
  alias Okovita.Content.{Entry, Model}
  alias Okovita.Timeline.Auditor

  import Ecto.Query

  @doc "Creates a content model in the tenant schema."
  @spec create_model(map(), String.t(), binary() | nil) ::
          {:ok, Model.t()} | {:error, Ecto.Changeset.t()}
  def create_model(attrs, prefix, actor_id \\ nil) do
    result =
      Multi.new()
      |> Multi.insert(:model, Model.changeset(%Model{}, attrs), prefix: prefix)
      |> Auditor.insert_audit(
        "model",
        "create",
        actor_id,
        fn %{model: model} ->
          {
            model.id,
            nil,
            %{
              slug: model.slug,
              name: model.name,
              schema_definition: model.schema_definition
            }
          }
        end,
        prefix: prefix
      )
      |> Multi.run(:auto_entry, fn repo, %{model: model} ->
        maybe_auto_create_component_entry(repo, model, prefix, actor_id)
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{model: model}} -> {:ok, model}
      {:error, :model, changeset, _} -> {:error, changeset}
      {:error, :auto_entry, reason, _} -> {:error, reason}
    end
  end

  @doc "Updates a content model in the tenant schema."
  @spec update_model(binary(), map(), String.t(), binary() | nil) ::
          {:ok, Model.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def update_model(model_id, attrs, prefix, actor_id \\ nil) do
    case get_model(model_id, prefix) do
      nil ->
        {:error, :not_found}

      model ->
        before_data = %{
          slug: model.slug,
          name: model.name,
          schema_definition: model.schema_definition
        }

        result =
          Multi.new()
          |> Multi.update(:model, Model.changeset(model, attrs), prefix: prefix)
          |> Auditor.insert_audit(
            "model",
            "update",
            actor_id,
            fn %{model: updated_model} ->
              {
                model.id,
                before_data,
                %{
                  slug: updated_model.slug,
                  name: updated_model.name,
                  schema_definition: updated_model.schema_definition
                }
              }
            end,
            prefix: prefix
          )
          |> Repo.transaction()

        case result do
          {:ok, %{model: model}} -> {:ok, model}
          {:error, :model, changeset, _} -> {:error, changeset}
        end
    end
  end

  @doc "Gets a content model by ID."
  def get_model(id, prefix) do
    Repo.get(Model, id, prefix: prefix)
  end

  @doc "Gets a content model by slug."
  def get_model_by_slug(slug, prefix) do
    Repo.one(from(m in Model, where: m.slug == ^slug), prefix: prefix)
  end

  @doc "Lists all content models."
  def list_models(prefix) do
    Repo.all(from(m in Model, order_by: [asc: m.name]), prefix: prefix)
  end

  @doc """
  Deletes a content model and all its entries.

  Also cleans orphaned relation references in other models' entries — any
  `relation` or `relation_many` field whose `target_model` matches the deleted
  model's slug will have its value cleared (set to `""` for relation, `[]` for
  relation_many).
  """
  @spec delete_model(binary(), String.t(), binary() | nil) ::
          {:ok, Model.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def delete_model(model_id, prefix, actor_id \\ nil) do
    case get_model(model_id, prefix) do
      nil ->
        {:error, :not_found}

      model ->
        before_data = %{
          slug: model.slug,
          name: model.name,
          schema_definition: model.schema_definition
        }

        result =
          Multi.new()
          |> Multi.run(:clean_references, fn _repo, _changes ->
            clean_orphaned_relation_references(model.slug, prefix)
            {:ok, :cleaned}
          end)
          |> Multi.delete_all(
            :delete_entries,
            from(e in Entry, where: e.model_id == ^model.id),
            prefix: prefix
          )
          |> Multi.delete(:model, model, prefix: prefix)
          |> Auditor.insert_audit(
            "model",
            "delete",
            actor_id,
            fn _changes ->
              {model.id, before_data, nil}
            end,
            prefix: prefix
          )
          |> Repo.transaction()

        case result do
          {:ok, %{model: model}} -> {:ok, model}
          {:error, :model, changeset, _} -> {:error, changeset}
        end
    end
  end

  # Scans all other models for relation/relation_many fields pointing to the
  # given model slug, then clears those values in the corresponding entries.
  defp clean_orphaned_relation_references(deleted_slug, prefix) do
    relation_types = ["relation", "relation_many"]

    list_models(prefix)
    |> Enum.each(fn model ->
      # Find fields in this model that reference the deleted model
      orphan_fields =
        model.schema_definition
        |> Enum.filter(fn {_key, attrs} ->
          attrs["field_type"] in relation_types and attrs["target_model"] == deleted_slug
        end)
        |> Enum.map(fn {key, attrs} -> {key, attrs["field_type"]} end)

      if orphan_fields != [] do
        entries =
          from(e in Entry, where: e.model_id == ^model.id)
          |> Repo.all(prefix: prefix)

        Enum.each(entries, fn entry ->
          new_data = clear_relation_fields(entry.data, orphan_fields)

          if new_data != entry.data do
            entry
            |> Ecto.Changeset.change(%{data: new_data})
            |> Repo.update!(prefix: prefix)
          end
        end)
      end
    end)
  end

  defp clear_relation_fields(data, orphan_fields) do
    Enum.reduce(orphan_fields, data, fn {key, type}, acc ->
      blank_value = if type == "relation_many", do: [], else: ""
      Map.put(acc, key, blank_value)
    end)
  end

  defp maybe_auto_create_component_entry(_repo, %{is_component: false}, _prefix, _actor_id) do
    {:ok, nil}
  end

  defp maybe_auto_create_component_entry(repo, model, prefix, actor_id) do
    empty_data = build_empty_component_data(model.schema_definition)
    slug = Okovita.Content.SlugGenerator.build(%{}, empty_data, model, prefix)
    string_data = Okovita.Content.Entries.Utils.to_string_keyed_map(empty_data)

    entry_attrs = %{
      slug: slug,
      model_id: model.id,
      data: string_data,
      published_at: if(model.publishable, do: nil, else: DateTime.utc_now())
    }

    with {:ok, entry} <- repo.insert(Entry.changeset(%Entry{}, entry_attrs), prefix: prefix),
         {:ok, _} <- log_component_entry_creation(repo, entry, prefix, actor_id) do
      {:ok, entry}
    end
  end

  defp build_empty_component_data(schema_definition) do
    Map.new(schema_definition, fn {key, def} ->
      {key, Okovita.FieldTypes.Registry.default_value(def["field_type"])}
    end)
  end

  defp log_component_entry_creation(repo, entry, prefix, actor_id) do
    Auditor.insert_audit(
      Multi.new(),
      "entry",
      "create",
      actor_id,
      fn _ ->
        {
          entry.id,
          nil,
          %{slug: entry.slug, data: entry.data}
        }
      end,
      prefix: prefix
    )
    |> repo.transaction()
  end
end
