defmodule Okovita.Tenants.Tenant do
  @moduledoc """
  Ecto schema for the tenants table (public schema).

  Each tenant gets its own PostgreSQL schema (`tenant_{id}`) with
  content_models, content_entries, and timeline tables.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tenants" do
    field :name, :string
    field :slug, :string
    field :status, Ecto.Enum, values: [:active, :suspended], default: :active
    field :deleted_at, :naive_datetime

    has_many :api_keys, Okovita.Tenants.ApiKey

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating a new tenant."
  def create_changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name, :slug])
    |> validate_format(:slug, ~r/^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/,
      message:
        "must be lowercase alphanumeric with optional hyphens, cannot start or end with a hyphen"
    )
    |> validate_length(:slug, min: 2, max: 63)
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint(:slug, name: :tenants_slug_active_index)
  end

  @doc "Changeset for suspending or soft-deleting a tenant."
  def status_changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:status, :deleted_at])
    |> validate_required([:status])
  end
end
