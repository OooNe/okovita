defmodule Okovita.FieldTypes.Number do
  @moduledoc "Float/decimal field type. Validates `min` and `max`."
  use Okovita.FieldTypes.Base

  import Ecto.Changeset

  @impl true
  def primitive_type, do: :float

  @impl true
  def cast(value) when is_float(value), do: {:ok, value}
  def cast(value) when is_integer(value), do: {:ok, value / 1}

  def cast(value) when is_binary(value) do
    case Float.parse(value) do
      {f, ""} -> {:ok, f}
      {f, _rest} -> {:ok, f}
      :error -> :error
    end
  end

  def cast(nil), do: {:ok, nil}
  def cast(_), do: :error

  @impl true
  def validate(changeset, field_name, options) do
    changeset
    |> maybe_validate(:min, field_name, options)
    |> maybe_validate(:max, field_name, options)
  end

  defp maybe_validate(changeset, :min, field_name, options) do
    case Map.get(options, "min") do
      nil -> changeset
      min -> validate_number(changeset, field_name, greater_than_or_equal_to: min)
    end
  end

  defp maybe_validate(changeset, :max, field_name, options) do
    case Map.get(options, "max") do
      nil -> changeset
      max -> validate_number(changeset, field_name, less_than_or_equal_to: max)
    end
  end
end
