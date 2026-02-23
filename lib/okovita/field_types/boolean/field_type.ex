defmodule Okovita.FieldTypes.Boolean do
  @moduledoc "Boolean field type. No additional validations."
  use Okovita.FieldTypes.Base

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
end
