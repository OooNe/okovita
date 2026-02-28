defmodule Okovita.FieldTypes.Registry do
  @moduledoc """
  Registry of available field types.

  Reads the `:field_types` config at startup and provides lookup functions.
  Uses an Agent for simple key-value storage.
  """
  use Agent

  @doc "Starts the registry, reading field types from application config."
  def start_link(_opts) do
    field_types = Application.get_env(:okovita, :field_types, %{})

    Agent.start_link(fn -> field_types end, name: __MODULE__)
  end

  @doc """
  Returns the module for the given field type name.
  Raises `ArgumentError` if the type is not registered.

  ## Example

      iex> Okovita.FieldTypes.Registry.get!("text")
      Okovita.FieldTypes.Text
  """
  @spec get!(String.t()) :: module()
  def get!(type_name) when is_binary(type_name) do
    case Agent.get(__MODULE__, &Map.get(&1, type_name)) do
      nil -> raise ArgumentError, "Unknown field type: #{inspect(type_name)}"
      module -> module
    end
  end

  @doc """
  Returns the list of registered type names as strings.

  ## Example

      iex> Okovita.FieldTypes.Registry.registered_types()
      ["boolean", "date", "datetime", "enum", "image", "image_gallery", "integer", "number", "relation", "text", "textarea"]
  """
  @spec registered_types() :: [String.t()]
  def registered_types do
    Agent.get(__MODULE__, &Map.keys(&1)) |> Enum.sort()
  end

  @doc """
  Returns the editor component module for the given field type name, or `nil` if not found.

  Resolution order:
  1. If the field type module exports `editor_component/0`, use its return value.
  2. Otherwise, look for `<FieldTypeModule>.Editor` by naming convention.
  3. Return `nil` if neither is found.

  ## Example

      iex> Okovita.FieldTypes.Registry.editor_for("image")
      Okovita.FieldTypes.Image.Editor
  """
  @spec editor_for(String.t()) :: module() | nil
  def editor_for(type_name) when is_binary(type_name) do
    case Agent.get(__MODULE__, &Map.get(&1, type_name)) do
      nil ->
        nil

      module ->
        Code.ensure_loaded?(module)

        cond do
          function_exported?(module, :editor_component, 0) ->
            module.editor_component()

          true ->
            # Convention: Okovita.FieldTypes.Image -> Okovita.FieldTypes.Image.Editor
            editor = Module.concat(module, Editor)
            if Code.ensure_loaded?(editor), do: editor, else: nil
        end
    end
  end

  @doc """
  Returns the configurator component module for the given field type name, or `nil` if not found.
  Used by ModelBuilder to render type-specific field configuration.
  """
  @spec configurator_for(String.t()) :: module() | nil
  def configurator_for(type_name) when is_binary(type_name) do
    case Agent.get(__MODULE__, &Map.get(&1, type_name)) do
      nil ->
        nil

      module ->
        Code.ensure_loaded?(module)

        cond do
          function_exported?(module, :configurator_component, 0) ->
            module.configurator_component()

          true ->
            # Convention: Okovita.FieldTypes.Relation -> Okovita.FieldTypes.Relation.Configurator
            configurator = Module.concat(module, Configurator)
            if Code.ensure_loaded?(configurator), do: configurator, else: nil
        end
    end
  end

  @doc """
  Returns the LiveView upload configuration `{max_entries, accept}` for the given
  field type, or `nil` if the type does not support file uploads.

  Delegates to the field type module's `upload_config/0` callback if implemented.

  ## Example

      iex> Okovita.FieldTypes.Registry.upload_config("image")
      {1, ~w(.jpg .jpeg .png .gif .webp)}

      iex> Okovita.FieldTypes.Registry.upload_config("text")
      nil
  """
  @spec upload_config(String.t()) :: {pos_integer(), [String.t()]} | nil
  def upload_config(type_name) when is_binary(type_name) do
    case Agent.get(__MODULE__, &Map.get(&1, type_name)) do
      nil ->
        nil

      module ->
        Code.ensure_loaded?(module)
        if function_exported?(module, :upload_config, 0), do: module.upload_config()
    end
  end

  @doc """
  Returns extra assigns for a field's editor component by delegating to the
  field type module's `form_assigns/3` callback.

  Falls back to an empty map `%{}` if the callback is not implemented.

  The caller is responsible for merging the result on top of the base assigns
  `%{name: field_name, value: raw_value}`.

  ## Example

      iex> Okovita.FieldTypes.Registry.form_assigns("enum", "status", %{"one_of" => ["a","b"]}, assigns)
      %{options: ["a", "b"]}
  """
  @spec form_assigns(String.t(), String.t(), map(), map()) :: map()
  def form_assigns(type_name, field_name, field_def, assigns) when is_binary(type_name) do
    case Agent.get(__MODULE__, &Map.get(&1, type_name)) do
      nil ->
        %{}

      module ->
        Code.ensure_loaded?(module)

        if function_exported?(module, :form_assigns, 3) do
          module.form_assigns(field_name, field_def, assigns)
        else
          %{}
        end
    end
  end

  @doc """
  Formats the value for the API response based on the field type module's implementation.
  Defaults to returning the value as-is if the field type doesn't implement a specific formatter.

  ## Example

      iex> Okovita.FieldTypes.Registry.format_api_response("image", raw_media, %{with_metadata: true})
      %{"id" => "...", "url" => "..."}
  """
  @spec format_api_response(String.t(), any(), map()) :: any()
  def format_api_response(type_name, value, opts \\ %{}) when is_binary(type_name) do
    case Agent.get(__MODULE__, &Map.get(&1, type_name)) do
      nil ->
        value

      module ->
        serializer = Module.concat(module, Serializer)

        if Code.ensure_loaded?(serializer) && function_exported?(serializer, :format, 2) do
          serializer.format(value, opts)
        else
          value
        end
    end
  end

  @doc """
  Returns the target repository domain for population (`:entry` or `:media`),
  or `nil` if the type does not support or require database population.
  """
  @spec population_target(String.t()) :: atom() | nil
  def population_target(type_name) when is_binary(type_name) do
    case Agent.get(__MODULE__, &Map.get(&1, type_name)) do
      nil ->
        nil

      module ->
        populator = Module.concat(module, Populator)

        if Code.ensure_loaded?(populator) && function_exported?(populator, :population_target, 0) do
          populator.population_target()
        else
          nil
        end
    end
  end

  @doc """
  Checks if the given field type's population target is `:entry`.
  """
  @spec targets_entry?(String.t()) :: boolean()
  def targets_entry?(type_name) when is_binary(type_name) do
    population_target(type_name) == :entry
  end

  @doc """
  Checks if the given field type's population target is `:media`.
  """
  @spec targets_media?(String.t()) :: boolean()
  def targets_media?(type_name) when is_binary(type_name) do
    population_target(type_name) == :media
  end

  @doc """
  Extracts UUIDs from the field's raw value by delegating to its `extract_references/1` callback.
  Returns an empty list `[]` if not implemented.
  """
  @spec extract_references(String.t(), any()) :: [String.t()]
  def extract_references(type_name, value) when is_binary(type_name) do
    case Agent.get(__MODULE__, &Map.get(&1, type_name)) do
      nil ->
        []

      module ->
        populator = Module.concat(module, Populator)

        if Code.ensure_loaded?(populator) && function_exported?(populator, :extract_references, 1) do
          populator.extract_references(value)
        else
          []
        end
    end
  end

  @doc """
  Populates the field's value using the fetched entities map.
  Delegates to `populate/3` on the field module or returns value as-is.
  """
  @spec populate(String.t(), any(), map(), map()) :: any()
  def populate(type_name, value, entities_map, opts \\ %{}) when is_binary(type_name) do
    case Agent.get(__MODULE__, &Map.get(&1, type_name)) do
      nil ->
        value

      module ->
        populator = Module.concat(module, Populator)

        if Code.ensure_loaded?(populator) && function_exported?(populator, :populate, 3) do
          populator.populate(value, entities_map, opts)
        else
          value
        end
    end
  end

  @doc """
  Builds a reverse lookup dynamic Ecto query using the field's Populator module.
  Falls back to returning the unchanged `acc` if the type does not implement it.
  """
  @spec reverse_lookup_query(String.t(), String.t(), String.t(), Ecto.Query.dynamic()) ::
          Ecto.Query.dynamic()
  def reverse_lookup_query(type_name, key, parent_id, acc) when is_binary(type_name) do
    case Agent.get(__MODULE__, &Map.get(&1, type_name)) do
      nil ->
        acc

      module ->
        populator = Module.concat(module, Populator)

        if Code.ensure_loaded?(populator) &&
             function_exported?(populator, :reverse_lookup_query, 3) do
          populator.reverse_lookup_query(key, parent_id, acc)
        else
          acc
        end
    end
  end
end
