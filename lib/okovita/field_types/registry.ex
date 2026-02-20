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
      Okovita.FieldTypes.Types.Text
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
      ["boolean", "date", "datetime", "enum", "integer", "number", "text", "textarea"]
  """
  @spec registered_types() :: [String.t()]
  def registered_types do
    Agent.get(__MODULE__, &Map.keys(&1)) |> Enum.sort()
  end
end
