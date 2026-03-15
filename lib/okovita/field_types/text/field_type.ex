defmodule Okovita.FieldTypes.Text do
  @moduledoc "Short text field type. Validates `max_length`."
  use Okovita.FieldTypes.Base

  import Ecto.Changeset

  @impl true
  def primitive_type, do: :string

  @impl true
  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(nil), do: {:ok, nil}
  def cast(_), do: :error

  @impl true
  def list_compatible?, do: true

  @impl true
  def validate(changeset, field_name, options) do
    changeset
    |> maybe_validate_min_length(field_name, options)
    |> maybe_validate_max_length(field_name, options)
    |> maybe_validate_regex(field_name, options)
  end

  defp maybe_validate_min_length(changeset, field_name, options) do
    case Map.get(options, "min_length") do
      nil -> changeset
      min when is_integer(min) -> validate_length(changeset, field_name, min: min)
      _ -> changeset
    end
  end

  defp maybe_validate_max_length(changeset, field_name, options) do
    case Map.get(options, "max_length") do
      nil -> changeset
      max when is_integer(max) -> validate_length(changeset, field_name, max: max)
      _ -> changeset
    end
  end

  defp maybe_validate_regex(changeset, field_name, options) do
    case Map.get(options, "validation_regex") do
      nil ->
        changeset

      "" ->
        changeset

      pattern when is_binary(pattern) ->
        case Regex.compile(pattern) do
          {:ok, regex} ->
            validate_format(changeset, field_name, regex,
              message: "does not match the required pattern"
            )

          {:error, _} ->
            add_error(changeset, field_name, "has an invalid validation pattern configured")
        end
    end
  end
end
