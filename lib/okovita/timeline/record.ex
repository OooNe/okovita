defmodule Okovita.Timeline.Record do
  @moduledoc """
  Ecto schema for timeline/audit records within a tenant schema.

  Tracks entity changes with before/after snapshots.
  Uses `timestamps(updated_at: false)` since audit records are immutable.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "timeline" do
    field :entity_id, :binary_id
    field :entity_type, :string
    field :action, :string
    field :actor_id, :binary_id
    field :before, :map
    field :after, :map

    timestamps(updated_at: false, type: :utc_datetime)
  end
end
