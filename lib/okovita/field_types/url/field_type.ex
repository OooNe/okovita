defmodule Okovita.FieldTypes.Url do
  @moduledoc "URL field type."
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
    # Simple validation using validate_format with a regex for demonstration
    # In a real scenario, this regex should be more robust
    validate_format(changeset, field_name, ~r/^https?:\/\//, message: "must be a valid URL")
  end
end
