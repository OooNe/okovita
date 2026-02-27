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
      nil -> nil
      module -> if function_exported?(module, :upload_config, 0), do: module.upload_config()
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
        if function_exported?(module, :form_assigns, 3) do
          module.form_assigns(field_name, field_def, assigns)
        else
          %{}
        end
    end
  end
end
