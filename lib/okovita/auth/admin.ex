defmodule Okovita.Auth.Admin do
  @moduledoc """
  Ecto schema for the admins table (public schema).

  Admins are either:
  - `super_admin` — no tenant association, manages all tenants
  - `tenant_admin` — associated with a specific tenant
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "admins" do
    field :email, :string
    field :hashed_password, :string
    field :role, Ecto.Enum, values: [:super_admin, :tenant_admin]

    # Virtual field for password input — never persisted
    field :password, :string, virtual: true, redact: true

    belongs_to :tenant, Okovita.Tenants.Tenant

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating a new admin."
  def create_changeset(admin, attrs) do
    admin
    |> cast(attrs, [:email, :password, :role, :tenant_id])
    |> validate_required([:email, :password, :role])
    |> validate_email()
    |> validate_role_tenant_consistency()
    |> hash_password()
    |> unique_constraint(:email)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
  end

  defp validate_role_tenant_consistency(changeset) do
    role = get_field(changeset, :role)
    tenant_id = get_field(changeset, :tenant_id)

    case {role, tenant_id} do
      {:super_admin, nil} -> changeset
      {:super_admin, _} -> add_error(changeset, :tenant_id, "must be nil for super_admin")
      {:tenant_admin, nil} -> add_error(changeset, :tenant_id, "is required for tenant_admin")
      {:tenant_admin, _} -> changeset
      _ -> changeset
    end
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        changeset
        |> validate_length(:password, min: 8, max: 72)
        |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
        |> delete_change(:password)
    end
  end

  @doc "Verifies the given password against the hashed password."
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
