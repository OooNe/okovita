defmodule Okovita.Repo.Migrations.Tenant.AddDimensionsToMedia do
  use Ecto.Migration

  def change do
    alter table(:media) do
      add :width, :integer
      add :height, :integer
    end
  end
end
