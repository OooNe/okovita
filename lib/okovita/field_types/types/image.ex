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
    cleaned = String.trim(value)
    if cleaned == "", do: {:ok, nil}, else: {:ok, cleaned}
  end

  def cast(nil), do: {:ok, nil}
  def cast(_), do: :error

  @impl true
  def validate(changeset, field_name, options) do
    changeset =
      validate_change(changeset, field_name, fn _, value ->
        # Ecto UUID regex check to ensure the media_id reference is a valid UUID format
        if Ecto.UUID.cast(value) == :error do
          [{field_name, "is not a valid media reference"}]
        else
          []
        end
      end)

    if max_length = options["max_length"] do
      validate_length(changeset, field_name, max: max_length)
    else
      changeset
    end
  end
end
