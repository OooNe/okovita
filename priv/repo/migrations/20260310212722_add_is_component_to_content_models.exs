defmodule Okovita.Repo.Migrations.AddIsComponentToContentModels do
  use Ecto.Migration

  def change do
    alter table(:content_models) do
      add :is_component, :boolean, default: false, null: false
    end
  end
end
