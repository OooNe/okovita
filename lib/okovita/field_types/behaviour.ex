defmodule Okovita.FieldTypes.Behaviour do
  @moduledoc """
  Behaviour for pluggable field types.

  Each field type module implements three callbacks:
  - `primitive_type/0` — the Ecto primitive used for schemaless changeset
  - `cast/1` — coerce raw input to the correct type
  - `validate/3` — apply field-type-specific validations to a changeset

  Optional callbacks:
  - `editor_component/0` — Phoenix.Component module for the editor UI
  - `upload_config/0` — LiveView upload configuration `{max_entries, accept}`
  - `form_assigns/3` — extra assigns to merge into the editor component's assigns
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

  @doc """
  Returns the Phoenix.Component module that renders the specific configuration UI
  for this field type inside ModelBuilder. Optional. Falls back to `<Module>.Configurator`.
  """
  @callback configurator_component() :: module()

  @doc """
  Returns LiveView upload configuration for this field type, or `nil` if the
  field type does not support direct file uploads.

  The return value `{max_entries, accept}` is used by `Registry.upload_config/1`
  to call `Phoenix.LiveView.allow_upload/3` at mount time.

  ## Example

      def upload_config, do: {1, ~w(.jpg .jpeg .png .gif .webp)}
  """
  @callback upload_config() :: {pos_integer(), [String.t()]} | nil

  @doc """
  Returns extra assigns to merge for the editor component of this field type.

  Called by `Registry.form_assigns/4` when building the props passed to an
  editor component. The returned map is merged on top of the base assigns
  `%{name: field_name, value: raw_value}`.

  `assigns` is the full LiveView assigns map (includes `:data`, `:uploads`,
  `:relation_options`, etc.).

  ## Example

      def form_assigns(field_name, field_def, assigns) do
        %{options: field_def["one_of"] || []}
      end
  """
  @callback form_assigns(
              field_name :: String.t(),
              field_def :: map(),
              assigns :: map()
            ) :: map()

  @optional_callbacks [
    editor_component: 0,
    configurator_component: 0,
    upload_config: 0,
    form_assigns: 3
  ]
end
