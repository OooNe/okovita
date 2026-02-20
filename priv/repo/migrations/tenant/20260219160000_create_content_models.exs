defmodule Okovita.Repo.Migrations.Tenant.CreateContentModels do
  use Ecto.Migration

  def change do
    create table(:content_models, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :string, null: false
      add :name, :string, null: false
      add :schema_definition, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:content_models, [:slug])
  end
end
