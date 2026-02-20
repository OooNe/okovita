defmodule Okovita.Content.Entry do
  @moduledoc """
  Ecto schema for content entries within a tenant schema.

  Each entry belongs to a `Model` and stores its dynamic data
  in the `data` column as a JSON map.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Okovita.Content.Model

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "content_entries" do
    field :slug, :string
    field :data, :map, default: %{}

    belongs_to :model, Model

    timestamps()
  end

  @required_fields ~w(slug model_id data)a

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_format(:slug, ~r/\A[a-z0-9][a-z0-9_-]*\z/,
      message:
        "must start with a letter or digit and contain only lowercase letters, digits, hyphens, and underscores"
    )
    |> unique_constraint([:model_id, :slug])
    |> foreign_key_constraint(:model_id)
  end

  def update_changeset(entry, attrs) do
    entry
    |> cast(attrs, [:slug, :data])
    |> validate_format(:slug, ~r/\A[a-z0-9][a-z0-9_-]*\z/,
      message:
        "must start with a letter or digit and contain only lowercase letters, digits, hyphens, and underscores"
    )
    |> unique_constraint([:model_id, :slug])
  end
end
