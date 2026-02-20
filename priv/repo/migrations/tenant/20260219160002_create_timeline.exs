defmodule Okovita.Repo.Migrations.Tenant.CreateTimeline do
  use Ecto.Migration

  def change do
    create table(:timeline, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :entity_id, :binary_id, null: false
      add :entity_type, :string, null: false
      add :action, :string, null: false
      add :actor_id, :binary_id
      add :before, :map
      add :after, :map

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create index(:timeline, [:entity_id, :entity_type])
    create index(:timeline, [:inserted_at])
  end
end
