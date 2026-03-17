defmodule Okovita.FieldTypes.Date do
  @moduledoc "Date field type. Validates optional `min` and `max` date range."
  use Okovita.FieldTypes.Base

  import Ecto.Changeset

  @impl true
  def value_type, do: :date

  @impl true
  def cast(%Date{} = value), do: {:ok, value}

  def cast(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
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
         {:ok, min_date} <- Date.from_iso8601(min_str) do
      validate_change(changeset, field_name, fn _, value ->
        if Date.compare(value, min_date) in [:gt, :eq],
          do: [],
          else: [{field_name, "must be on or after #{min_str}"}]
      end)
    else
      _ -> changeset
    end
  end

  defp maybe_validate_max(changeset, field_name, options) do
    with max_str when is_binary(max_str) <- Map.get(options, "max"),
         {:ok, max_date} <- Date.from_iso8601(max_str) do
      validate_change(changeset, field_name, fn _, value ->
        if Date.compare(value, max_date) in [:lt, :eq],
          do: [],
          else: [{field_name, "must be on or before #{max_str}"}]
      end)
    else
      _ -> changeset
    end
  end
end
