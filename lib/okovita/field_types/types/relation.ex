defmodule Okovita.FieldTypes.Types.Relation do
  @moduledoc """
  Relation field type.

  Represents a reference to an entry in another content model.
  Stores the ID (UUID) of the target entry.
  """
  @behaviour Okovita.FieldTypes.Behaviour

  import Ecto.Changeset

  @impl true
  def primitive_type, do: :string

  @impl true
  def cast(value) do
    case Ecto.Type.cast(:string, value) do
      {:ok, val} -> {:ok, val}
      _ -> :error
    end
  end

  @impl true
  def validate(changeset, field, _def) do
    # Ensure it's a valid UUID format
    changeset
    |> validate_format(field, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
      message: "must be a valid UUID"
    )
  end
end
