defmodule Okovita.FieldTypes.Behaviour do
  @moduledoc """
  Behaviour for pluggable field types.

  Each field type module implements three callbacks:
  - `primitive_type/0` — the Ecto primitive used for schemaless changeset
  - `cast/1` — coerce raw input to the correct type
  - `validate/3` — apply field-type-specific validations to a changeset
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
end
