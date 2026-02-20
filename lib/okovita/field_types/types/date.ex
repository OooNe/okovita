defmodule Okovita.FieldTypes.Types.Date do
  @moduledoc "Date field type. No additional validations."
  @behaviour Okovita.FieldTypes.Behaviour

  @impl true
  def primitive_type, do: :date

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
  def validate(changeset, _field_name, _options), do: changeset
end
