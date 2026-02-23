defmodule Okovita.FieldTypes.Integer do
  @moduledoc "Integer field type. Validates `min` and `max`."
  use Okovita.FieldTypes.Base

  import Ecto.Changeset

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
