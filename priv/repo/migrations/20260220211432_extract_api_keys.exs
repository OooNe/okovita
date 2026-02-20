defmodule Okovita.Repo.Migrations.ExtractApiKeys do
  use Ecto.Migration

  def change do
    # Remove the legacy hash from tenants
    alter table(:tenants) do
      remove :api_key_hash, :string
    end

    create table(:okovita_api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :token_hash, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:okovita_api_keys, [:tenant_id])
    create unique_index(:okovita_api_keys, [:token_hash])
  end
end
