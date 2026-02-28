defmodule Okovita.Content.Entries.Utils do
  @moduledoc """
  Utility functions for Content.Entries operations.
  """

  @doc "Checks if a given string is a valid UUID."
  def is_uuid?(id) when is_binary(id) do
    match?({:ok, _}, Ecto.UUID.cast(id))
  end

  def is_uuid?(_), do: false

  @doc "Converts atom keys in a map to string keys."
  def to_string_keyed_map(data) when is_map(data) do
    Enum.into(data, %{}, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  @doc "Conditionally puts a key/value pair into a map if the value is not nil."
  def maybe_put(map, _key, nil), do: map
  def maybe_put(map, key, value), do: Map.put(map, key, value)
end
