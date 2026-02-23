defmodule Okovita.FieldTypes.RichText do
  @moduledoc """
  Rich Text field type. Stores content as a JSON map (ProseMirror/Tiptap document format).
  """
  use Okovita.FieldTypes.Base

  @impl true
  def primitive_type, do: :map

  @impl true
  def cast(nil), do: {:ok, %{}}
  def cast(value) when is_map(value), do: {:ok, value}

  def cast(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, map} when is_map(map) -> {:ok, map}
      _ -> :error
    end
  end

  def cast(_), do: :error
end
