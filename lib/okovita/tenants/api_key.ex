defmodule Okovita.Tenants.ApiKey do
  @moduledoc "Ecto schema for tenant API keys."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "okovita_api_keys" do
    field :name, :string
    field :token_hash, :string

    belongs_to :tenant, Okovita.Tenants.Tenant

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :token_hash, :tenant_id])
    |> validate_required([:name, :token_hash, :tenant_id])
    |> unique_constraint(:token_hash)
  end
end
