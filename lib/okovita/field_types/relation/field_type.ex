defmodule Okovita.FieldTypes.Relation do
  @moduledoc """
  Relation field type.

  Represents a reference to an entry in another content model.
  Stores the ID (UUID) of the target entry.
  """
  use Okovita.FieldTypes.Base

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
    validate_format(
      changeset,
      field,
      ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
      message: "must be a valid UUID"
    )
  end

  @impl true
  def form_assigns(field_name, _field_def, assigns),
    do: %{options: Map.get(assigns.relation_options, field_name, [])}
end
