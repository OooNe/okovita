defmodule Okovita.FieldTypes.Types.Image do
  @moduledoc """
  Image field type. Stores the S3 URL to the uploaded image as a string.
  """
  @behaviour Okovita.FieldTypes.Behaviour

  import Ecto.Changeset

  @impl true
  def primitive_type, do: :string

  @impl true
  def cast(value) when is_binary(value) do
    if String.trim(value) == "" do
      {:ok, nil}
    else
      {:ok, String.trim(value)}
    end
  end

  def cast(nil), do: {:ok, nil}
  def cast(_), do: :error

  @impl true
  def validate(changeset, field_name, options) do
    changeset =
      validate_format(changeset, field_name, ~r/^https?:\/\//, message: "must be a valid URL")

    if max_length = options["max_length"] do
      validate_length(changeset, field_name, max: max_length)
    else
      changeset
    end
  end
end
