defmodule Okovita.Content.Entries.Queries do
  @moduledoc """
  Database query builders for content entries, specifically for handling
  complex JSONB relations.
  """

  import Ecto.Query
  alias Okovita.Repo
  alias Okovita.Content.{Entry, Models, Entries}

  @doc """
  Lists child entries associated with a parent entry via relation fields.

  It resolves the models and checks if a valid `parent_entry` exists. If so, it looks
  up all relationship keys inside the `child_model` that point back to the `parent_model_slug`.
  Using those keys, it dynamically builds query filters to find any child entries
  where the `data ->> "key"` (or `data -> "jsonb_array"`) contains the `parent_id`.

  ## Parameters
    - `parent_id`: ID of the entry that we are looking for inside child relations.
    - `parent_model_slug`: Slug of the parent model (used to ensure safety and find the origin model).
    - `child_model_slug`: Slug of the child model we want to list entries for.
    - `prefix`: Tenant prefix for Repo queries.

  Returns `{child_model, entries}` or `nil` if validation steps fail (e.g., parent not found).
  """
  def list_entries_by_parent(parent_id, parent_model_slug, child_model_slug, prefix) do
    with %{id: p_id} <- Models.get_model_by_slug(parent_model_slug, prefix),
         %{} = child_model <- Models.get_model_by_slug(child_model_slug, prefix),
         %{model_id: ^p_id} <- Entries.get_entry(parent_id, prefix) do
      child_model
      |> Okovita.Content.Entries.Schema.get_relation_keys_for_parent(parent_model_slug)
      |> do_list_entries_by_parent(child_model, parent_id, prefix)
    else
      _ -> nil
    end
  end

  defp do_list_entries_by_parent([], child_model, _parent_id, _prefix), do: {child_model, []}

  defp do_list_entries_by_parent(
         relation_keys,
         %{id: child_model_id} = child_model,
         parent_id,
         prefix
       ) do
    filters = build_relation_filters(relation_keys, parent_id)

    entries =
      from(e in Entry,
        where: e.model_id == ^child_model_id,
        where: ^filters,
        order_by: [desc: e.inserted_at]
      )
      |> Repo.all(prefix: prefix)

    {child_model, entries}
  end

  defp build_relation_filters(relation_keys, parent_id) do
    Enum.reduce(relation_keys, dynamic([e], false), fn {key, type}, acc ->
      Okovita.FieldTypes.Registry.reverse_lookup_query(type, key, parent_id, acc)
    end)
  end
end
