defmodule Okovita.FieldTypes.Types.Enum do
  @moduledoc """
  Enum field type. Requires `one_of` validations option — a list of
  allowed string values. Validates inclusion.
  """
  @behaviour Okovita.FieldTypes.Behaviour

  @impl true
  def primitive_type, do: :string

  @impl true
  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(nil), do: {:ok, nil}
  def cast(_), do: :error

  @impl true
  def validate(changeset, field_name, options) do
    case Map.get(options, "one_of") do
      nil ->
        Ecto.Changeset.add_error(changeset, field_name, "enum field must define one_of")

      values when is_list(values) ->
        Ecto.Changeset.validate_inclusion(changeset, field_name, values)

      _ ->
        Ecto.Changeset.add_error(changeset, field_name, "one_of must be a list")
    end
  end
end
