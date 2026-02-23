defmodule Okovita.FieldTypes.Textarea do
  @moduledoc "Long text field type. Validates `max_length`."
  use Okovita.FieldTypes.Base

  import Ecto.Changeset

  @impl true
  def primitive_type, do: :string

  @impl true
  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(nil), do: {:ok, nil}
  def cast(_), do: :error

  @impl true
  def validate(changeset, field_name, options) do
    case Map.get(options, "max_length") do
      nil -> changeset
      max -> validate_length(changeset, field_name, max: max)
    end
  end
end
