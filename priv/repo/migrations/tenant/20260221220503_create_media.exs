defmodule Okovita.Repo.Migrations.CreateMedia do
  use Ecto.Migration

  def change do
    create table(:media, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :file_name, :string, null: false
      add :url, :string, null: false
      add :mime_type, :string, null: false
      add :size, :integer

      timestamps()
    end
  end
end
