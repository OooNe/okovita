defmodule Okovita.Timeline do
  @moduledoc """
  Context for timeline/audit operations.

  Provides `timeline_multi/5` to compose timeline record insertion
  into an `Ecto.Multi` chain.
  """
  alias Okovita.Timeline.Record

  @doc """
  Returns an `Ecto.Multi` step that inserts a timeline record.

  ## Parameters
    - `multi` — the Ecto.Multi to append to
    - `step_name` — atom name for the Multi step (e.g. `:timeline`)
    - `attrs` — map with keys: `entity_id`, `entity_type`, `action`, `actor_id`, `before`, `after`
    - `prefix` — the tenant schema prefix

  ## Example

      Multi.new()
      |> Multi.insert(:entry, entry_changeset, prefix: prefix)
      |> Timeline.timeline_multi(:timeline, %{
        entity_id: entry_id,
        entity_type: "entry",
        action: "create",
        actor_id: admin_id,
        before: nil,
        after: data
      }, prefix)
  """
  @spec timeline_multi(Ecto.Multi.t(), atom(), map(), String.t()) :: Ecto.Multi.t()
  def timeline_multi(multi, step_name, attrs, prefix) do
    Ecto.Multi.insert(
      multi,
      step_name,
      fn _changes ->
        %Record{}
        |> Ecto.Changeset.change(attrs)
      end,
      prefix: prefix
    )
  end

  @doc "Inserts a timeline record directly."
  def create_record(attrs, prefix) do
    %Record{}
    |> Ecto.Changeset.change(attrs)
    |> Okovita.Repo.insert(prefix: prefix)
  end

  @doc "Lists timeline records for an entity."
  def list_records(entity_id, entity_type, prefix) do
    import Ecto.Query

    from(r in Record,
      where: r.entity_id == ^entity_id and r.entity_type == ^entity_type,
      order_by: [desc: r.inserted_at]
    )
    |> Okovita.Repo.all(prefix: prefix)
  end
end
