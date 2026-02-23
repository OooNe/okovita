defmodule Okovita.FieldTypes.Behaviour do
  @moduledoc """
  Behaviour for pluggable field types.

  Each field type module implements three callbacks:
  - `primitive_type/0` — the Ecto primitive used for schemaless changeset
  - `cast/1` — coerce raw input to the correct type
  - `validate/3` — apply field-type-specific validations to a changeset

  An optional fourth callback `editor_component/0` may be implemented to
  declare the Phoenix.Component module used to render this field's editor UI.
  The convention (used automatically by `Registry.editor_for/1`) is that if
  the module `Foo.FieldType` does not declare `editor_component/0`, the
  registry will look for `Foo.Editor` by module naming convention.
  """

  @doc "Returns the Ecto primitive type (e.g. `:string`, `:integer`, `:float`, `:boolean`, `:date`, `:utc_datetime`)."
  @callback primitive_type() :: atom()

  @doc """
  Casts a raw value to the field's primitive type.
  Returns `{:ok, cast_value}` or `:error`.
  """
  @callback cast(value :: any()) :: {:ok, any()} | :error

  @doc """
  Applies field-type-specific validations to the changeset for `field_name`.
  `options` is the field definition map from schema_definition (may contain
  keys like `max_length`, `min`, `max`, `one_of`, etc.).
  Returns the (possibly modified) changeset.
  """
  @callback validate(
              changeset :: Ecto.Changeset.t(),
              field_name :: atom(),
              options :: map()
            ) :: Ecto.Changeset.t()

  @doc """
  Returns the Phoenix.Component module that renders the editor UI for this field type.
  Optional: if not implemented, `Registry.editor_for/1` falls back to the naming
  convention `<FieldTypeModule>.Editor` (e.g. `Okovita.FieldTypes.Image.Editor`).
  """
  @callback editor_component() :: module()
  @optional_callbacks [editor_component: 0]
end
