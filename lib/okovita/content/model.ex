defmodule Okovita.Content.Model do
  @moduledoc """
  Ecto schema for content models within a tenant schema.

  The `schema_definition` field is a JSON map defining the model's fields:

      %{
        "title" => %{"field_type" => "text", "label" => "Title", "required" => true, "max_length" => 200},
        "body"  => %{"field_type" => "textarea", "label" => "Body", "required" => true}
      }
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Okovita.FieldTypes.Registry

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  schema "content_models" do
    field :slug, :string
    field :name, :string
    field :schema_definition, :map, default: %{}

    timestamps()
  end

  @required_fields ~w(slug name schema_definition)a
  @optional_fields ~w()a

  def changeset(model, attrs) do
    model
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_format(:slug, ~r/\A[a-z0-9][a-z0-9_-]*\z/,
      message:
        "must start with a letter or digit and contain only lowercase letters, digits, hyphens, and underscores"
    )
    |> unique_constraint(:slug)
    |> validate_schema_definition()
  end

  defp validate_schema_definition(changeset) do
    case get_change(changeset, :schema_definition) do
      nil ->
        changeset

      definition when is_map(definition) ->
        registered = Registry.registered_types()

        Enum.reduce(definition, changeset, fn {field_name, field_def}, cs ->
          cond do
            not String.match?(field_name, ~r/^[a-zA-Z0-9_-]+$/) ->
              add_error(
                cs,
                :schema_definition,
                "field key '#{field_name}' is invalid (only letters, numbers, hyphens, and underscores are allowed)"
              )

            not is_map(field_def) ->
              add_error(cs, :schema_definition, "field '#{field_name}' must be a map")

            not Map.has_key?(field_def, "field_type") ->
              add_error(cs, :schema_definition, "field '#{field_name}' is missing 'field_type'")

            not Map.has_key?(field_def, "label") ->
              add_error(cs, :schema_definition, "field '#{field_name}' is missing 'label'")

            not Map.has_key?(field_def, "required") ->
              add_error(cs, :schema_definition, "field '#{field_name}' is missing 'required'")

            field_def["field_type"] not in registered ->
              add_error(
                cs,
                :schema_definition,
                "field '#{field_name}' has unknown field_type '#{field_def["field_type"]}'"
              )

            true ->
              cs
          end
        end)

      _ ->
        add_error(changeset, :schema_definition, "must be a map")
    end
  end
end
