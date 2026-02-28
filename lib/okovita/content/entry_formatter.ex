defmodule Okovita.Content.EntryFormatter do
  @moduledoc """
  Provides formatting functions for converting Entry objects into JSON representations
  suitable for the REST API responses.
  """

  alias Okovita.Content.Entry

  @doc """
  Formats an Entry object, embedding necessary structure based on its schema
  or keeping it strictly to its data if no model is provided.
  """
  def format(%Entry{} = entry, model, with_metadata) do
    data = Map.put(entry.data || %{}, "id", entry.id)

    formatted_data =
      if model && model.schema_definition do
        format_populate_fields(data, model.schema_definition, with_metadata)
      else
        data
      end

    if with_metadata do
      %{
        metadata: %{
          slug: entry.slug,
          model_id: entry.model_id,
          model_slug: if(model, do: model.slug),
          inserted_at: entry.inserted_at,
          updated_at: entry.updated_at
        },
        data: formatted_data
      }
    else
      formatted_data
    end
  end

  defp format_populate_fields(data, schema_definition, with_metadata) do
    Enum.reduce(schema_definition, data, fn {key, attrs}, acc_data ->
      case Map.get(acc_data, key) do
        nil ->
          acc_data

        value ->
          formatted_value =
            Okovita.FieldTypes.Registry.format_api_response(
              attrs["field_type"],
              value,
              %{with_metadata: with_metadata}
            )

          Map.put(acc_data, key, formatted_value)
      end
    end)
  end
end
