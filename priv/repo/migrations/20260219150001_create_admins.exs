defmodule Okovita.Repo.Migrations.CreateAdmins do
  use Ecto.Migration

  def change do
    create table(:admins, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :hashed_password, :string, null: false
      add :role, :string, null: false
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:admins, [:email])
    create index(:admins, [:tenant_id])

    # CHECK constraint: super_admin must have no tenant, tenant_admin must have a tenant
    execute(
      """
      ALTER TABLE admins ADD CONSTRAINT admins_role_tenant_check
        CHECK (
          (role = 'super_admin' AND tenant_id IS NULL)
          OR
          (role = 'tenant_admin' AND tenant_id IS NOT NULL)
        )
      """,
      "ALTER TABLE admins DROP CONSTRAINT admins_role_tenant_check"
    )
  end
end
