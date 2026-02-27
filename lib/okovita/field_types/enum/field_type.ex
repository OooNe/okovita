defmodule Okovita.FieldTypes.Enum do
  @moduledoc """
  Enum field type. Requires `one_of` option — a list of allowed string values.
  Validates inclusion.
  """
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
    case Map.get(options, "one_of") do
      nil ->
        add_error(changeset, field_name, "enum field must define one_of")

      values when is_list(values) ->
        validate_inclusion(changeset, field_name, values)

      _ ->
        add_error(changeset, field_name, "one_of must be a list")
    end
  end

  @impl true
  def form_assigns(_field_name, field_def, _assigns),
    do: %{options: field_def["one_of"] || []}
end
