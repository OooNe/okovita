defmodule Okovita.FieldTypes.RelationMany.Serializer do
  @moduledoc """
  Serializer for the RelationMany field type.
  Formats a list of fully populated entries or array of string IDs when mapping JSON.
  """

  def format(list, options) when is_list(list) do
    with_metadata = Map.get(options, :with_metadata, false)

    Enum.map(list, fn
      %Okovita.Content.Entry{} = entry ->
        model = if Ecto.assoc_loaded?(entry.model) && entry.model, do: entry.model, else: nil
        Okovita.Content.EntryFormatter.format(entry, model, with_metadata)

      id when is_binary(id) ->
        %{"id" => id}

      other ->
        other
    end)
  end

  def format(other, _options), do: other
end
