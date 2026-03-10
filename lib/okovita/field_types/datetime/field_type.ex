defmodule Okovita.FieldTypes.Datetime do
  @moduledoc "UTC datetime field type. Validates optional `min` and `max` datetime range."
  use Okovita.FieldTypes.Base

  import Ecto.Changeset

  @impl true
  def primitive_type, do: :utc_datetime

  @impl true
  def cast(%DateTime{} = value), do: {:ok, value}

  def cast(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> {:ok, dt}
      {:error, _} -> :error
    end
  end

  def cast(nil), do: {:ok, nil}
  def cast(_), do: :error

  @impl true
  def validate(changeset, field_name, options) do
    changeset
    |> maybe_validate_min(field_name, options)
    |> maybe_validate_max(field_name, options)
  end

  defp maybe_validate_min(changeset, field_name, options) do
    with min_str when is_binary(min_str) <- Map.get(options, "min"),
         {:ok, min_dt, _} <- DateTime.from_iso8601(min_str) do
      validate_change(changeset, field_name, fn _, value ->
        if DateTime.compare(value, min_dt) in [:gt, :eq],
          do: [],
          else: [{field_name, "must be on or after #{min_str}"}]
      end)
    else
      _ -> changeset
    end
  end

  defp maybe_validate_max(changeset, field_name, options) do
    with max_str when is_binary(max_str) <- Map.get(options, "max"),
         {:ok, max_dt, _} <- DateTime.from_iso8601(max_str) do
      validate_change(changeset, field_name, fn _, value ->
        if DateTime.compare(value, max_dt) in [:lt, :eq],
          do: [],
          else: [{field_name, "must be on or before #{max_str}"}]
      end)
    else
      _ -> changeset
    end
  end
end
