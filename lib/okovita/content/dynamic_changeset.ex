defmodule Okovita.Content.DynamicChangeset do
  @moduledoc """
  Builds a schemaless Ecto changeset from a content model's `schema_definition`
  and raw input data.

  The `schema_definition` is a map of field definitions:

      %{
        "title" => %{"field_type" => "text", "label" => "Title", "required" => true, "max_length" => 200},
        "body"  => %{"field_type" => "textarea", "label" => "Body", "required" => true},
        "count" => %{"field_type" => "integer", "label" => "Count", "required" => false, "min" => 0}
      }

  `build/2` returns a changeset with all fields cast and validated per their type definition.
  """

  alias Okovita.FieldTypes.Registry

  @doc """
  Builds a schemaless changeset from a schema_definition and raw data.

  1. Extracts field definitions from schema_definition
  2. Looks up each field's type module from the Registry
  3. Builds a types map for `Ecto.Changeset.cast/4`
  4. Casts all fields
  5. Validates required fields
  6. Runs per-field-type validations

  Returns `{:ok, validated_data}` if valid, `{:error, changeset}` if invalid.
  """
  @spec build(map(), map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def build(schema_definition, data) when is_map(schema_definition) and is_map(data) do
    fields = schema_definition

    # Build the types map from schema_definition
    types =
      fields
      |> Enum.into(%{}, fn {field_name, field_def} ->
        type_module = Registry.get!(field_def["field_type"])
        {String.to_atom(field_name), type_module.primitive_type()}
      end)

    field_atoms = Map.keys(types)

    # Build schemaless changeset
    changeset =
      {%{}, types}
      |> Ecto.Changeset.cast(data, field_atoms)

    # Validate required fields
    required_fields =
      fields
      |> Enum.filter(fn {_name, def} -> def["required"] == true end)
      |> Enum.map(fn {name, _def} -> String.to_atom(name) end)

    changeset = Ecto.Changeset.validate_required(changeset, required_fields)

    # Apply per-type validations
    changeset =
      Enum.reduce(fields, changeset, fn {field_name, field_def}, cs ->
        type_module = Registry.get!(field_def["field_type"])
        type_module.validate(cs, String.to_atom(field_name), field_def)
      end)

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end

  @doc """
  Same as `build/2` but returns only the changeset (without ok/error wrapping).
  Useful when you need to compose with Ecto.Multi.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(schema_definition, data) do
    fields = schema_definition

    types =
      fields
      |> Enum.into(%{}, fn {field_name, field_def} ->
        type_module = Registry.get!(field_def["field_type"])
        {String.to_atom(field_name), type_module.primitive_type()}
      end)

    field_atoms = Map.keys(types)

    cs =
      {%{}, types}
      |> Ecto.Changeset.cast(data, field_atoms)

    required_fields =
      fields
      |> Enum.filter(fn {_name, def} -> def["required"] == true end)
      |> Enum.map(fn {name, _def} -> String.to_atom(name) end)

    cs = Ecto.Changeset.validate_required(cs, required_fields)

    Enum.reduce(fields, cs, fn {field_name, field_def}, acc ->
      type_module = Registry.get!(field_def["field_type"])
      type_module.validate(acc, String.to_atom(field_name), field_def)
    end)
  end
end
