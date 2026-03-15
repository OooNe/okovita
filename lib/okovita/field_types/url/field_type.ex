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
  def list_compatible?, do: true

  @impl true
  def validate(changeset, field_name, options) do
    changeset
    |> validate_format(field_name, ~r/^https?:\/\//, message: "must be a valid URL")
    |> maybe_validate_regex(field_name, options)
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
