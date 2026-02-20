defmodule Okovita.Repo.Migrations.CreateTenants do
  use Ecto.Migration

  def change do
    create table(:tenants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :api_key_hash, :string, null: false
      add :status, :string, null: false, default: "active"
      add :deleted_at, :naive_datetime

      timestamps(type: :utc_datetime)
    end

    # Partial unique index — only enforce uniqueness on non-deleted tenants
    create unique_index(:tenants, [:slug],
             where: "deleted_at IS NULL",
             name: :tenants_slug_active_index
           )

    create index(:tenants, [:api_key_hash])
  end
end
