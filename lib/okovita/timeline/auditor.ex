defmodule Okovita.Timeline.Auditor do
  @moduledoc """
  Service module for appending timeline audit logs to an existing Ecto.Multi structure.
  """

  alias Ecto.Multi
  alias Okovita.Timeline.Record

  @doc """
  Appends a timeline insertion operation to an Ecto.Multi structure.

  ## Parameters
    * `multi` - The Ecto.Multi structure to append to.
    * `name` - The name of the multi operation (e.g., `:timeline`).
    * `entity_type` - The string representing what's being audited (e.g., "model", "entry").
    * `action` - The string representing the action (e.g., "create", "update", "delete").
    * `actor_id` - ID of the user performing the action (optional).
    * `entity_mapper_fn` - A function `(%{deps} -> {entity_id, before_data, after_data})` that extracts audit data from previous Ecto.Multi steps.
    * `opts` - Keyword list options containing `prefix` (mandatory for tenant contexts).
  """
  @spec insert_audit(
          Multi.t(),
          atom(),
          String.t(),
          String.t(),
          binary() | nil,
          (map() -> {binary(), map() | nil, map() | nil}),
          keyword()
        ) :: Multi.t()
  def insert_audit(
        multi,
        name \\ :timeline,
        entity_type,
        action,
        actor_id,
        entity_mapper_fn,
        opts
      ) do
    prefix = Keyword.fetch!(opts, :prefix)

    Multi.insert(
      multi,
      name,
      fn deps ->
        {entity_id, before_data, after_data} = entity_mapper_fn.(deps)

        %Record{}
        |> Ecto.Changeset.change(%{
          entity_id: entity_id,
          entity_type: entity_type,
          action: action,
          actor_id: actor_id,
          before: before_data,
          after: after_data
        })
      end,
      prefix: prefix
    )
  end
end
