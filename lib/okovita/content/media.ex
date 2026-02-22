defmodule Okovita.Content.Media do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "media" do
    field :file_name, :string
    field :url, :string
    field :mime_type, :string
    field :size, :integer

    timestamps()
  end

  @doc false
  def changeset(media, attrs) do
    media
    |> cast(attrs, [:file_name, :url, :mime_type, :size])
    |> validate_required([:file_name, :url, :mime_type])
  end
end
