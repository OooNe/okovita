defmodule Okovita.FieldTypes.Types.Datetime do
  @moduledoc "UTC datetime field type. No additional validations."
  @behaviour Okovita.FieldTypes.Behaviour

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
  def validate(changeset, _field_name, _options), do: changeset
end
