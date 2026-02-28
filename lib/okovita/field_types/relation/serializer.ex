defmodule Okovita.FieldTypes.Relation.Serializer do
  @moduledoc """
  Serializer for the Relation field type.
  Formats either a fully populated Entry standard structure or a default JSON fallback
  object for nested unexpanded API relations.
  """

  def format(%Okovita.Content.Entry{} = entry, options) do
    with_metadata = Map.get(options, :with_metadata, false)
    model = if Ecto.assoc_loaded?(entry.model) && entry.model, do: entry.model, else: nil
    Okovita.Content.EntryFormatter.format(entry, model, with_metadata)
  end

  def format(id, _options) when is_binary(id) do
    %{"id" => id}
  end

  def format(other, _options), do: other
end
