defmodule Okovita.Content do
  @moduledoc """
  Context for content model and entry management within a tenant schema.

  All operations take a `prefix` parameter (tenant schema name) and
  run scoped to that schema. CRUD operations integrate with the Timeline
  for audit logging and with sync pipelines for data transformation.
  """

  alias Okovita.Content.Models
  alias Okovita.Content.Entries

  # ── Models ────────────────────────────────────────────────────────

  defdelegate create_model(attrs, prefix, actor_id \\ nil), to: Models
  defdelegate update_model(model_id, attrs, prefix, actor_id \\ nil), to: Models
  defdelegate get_model(id, prefix), to: Models
  defdelegate get_model_by_slug(slug, prefix), to: Models
  defdelegate list_models(prefix), to: Models

  # ── Entries ───────────────────────────────────────────────────────

  defdelegate create_entry(model_id, attrs, prefix, actor_id \\ nil), to: Entries
  defdelegate update_entry(entry_id, model_id, attrs, prefix, actor_id \\ nil), to: Entries
  defdelegate delete_entry(entry_id, prefix, actor_id \\ nil), to: Entries
  defdelegate get_entry(id, prefix), to: Entries
  defdelegate list_entries(model_id, prefix), to: Entries
  defdelegate populate_relations(entries, model, prefix, opts \\ []), to: Entries
end
