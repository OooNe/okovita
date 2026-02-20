defmodule Okovita.FieldTypes.Types.Integer do
  @moduledoc "Integer field type. Validates `min` and `max`."
  @behaviour Okovita.FieldTypes.Behaviour

  @impl true
  def primitive_type, do: :integer

  @impl true
  def cast(value) when is_integer(value), do: {:ok, value}
  def cast(value) when is_float(value), do: {:ok, trunc(value)}

  def cast(value) when is_binary(value) do
    case Integer.parse(value) do
      {i, ""} -> {:ok, i}
      {i, _rest} -> {:ok, i}
      :error -> :error
    end
  end

  def cast(nil), do: {:ok, nil}
  def cast(_), do: :error

  @impl true
  def validate(changeset, field_name, options) do
    changeset
    |> maybe_validate_number(:min, field_name, options)
    |> maybe_validate_number(:max, field_name, options)
  end

  defp maybe_validate_number(changeset, :min, field_name, options) do
    case Map.get(options, "min") do
      nil -> changeset
      min -> Ecto.Changeset.validate_number(changeset, field_name, greater_than_or_equal_to: min)
    end
  end

  defp maybe_validate_number(changeset, :max, field_name, options) do
    case Map.get(options, "max") do
      nil -> changeset
      max -> Ecto.Changeset.validate_number(changeset, field_name, less_than_or_equal_to: max)
    end
  end
end
