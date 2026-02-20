defmodule Okovita.FieldTypes.Types.Boolean do
  @moduledoc "Boolean field type. No additional validations."
  @behaviour Okovita.FieldTypes.Behaviour

  @impl true
  def primitive_type, do: :boolean

  @impl true
  def cast(value) when is_boolean(value), do: {:ok, value}
  def cast("true"), do: {:ok, true}
  def cast("false"), do: {:ok, false}
  def cast("1"), do: {:ok, true}
  def cast("0"), do: {:ok, false}
  def cast(1), do: {:ok, true}
  def cast(0), do: {:ok, false}
  def cast(nil), do: {:ok, nil}
  def cast(_), do: :error

  @impl true
  def validate(changeset, _field_name, _options), do: changeset
end
