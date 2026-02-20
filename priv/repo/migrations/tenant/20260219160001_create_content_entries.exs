defmodule Okovita.Repo.Migrations.Tenant.CreateContentEntries do
  use Ecto.Migration

  def change do
    create table(:content_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :string, null: false
      add :data, :map, null: false, default: %{}
      add :model_id, references(:content_models, type: :binary_id, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:content_entries, [:model_id, :slug])
    create index(:content_entries, [:model_id])
  end
end
