defmodule Okovita.FieldTypes.RelationMany do
  @moduledoc """
  RelationMany field type.

  Represents a list of references to entries in another content model.
  Stores a list of UUIDs (strings) of the target entries.

  ## Format in DB

      ["uuid-1", "uuid-2", "uuid-3"]

  ## Schema definition example

      %{
        "tags" => %{
          "field_type" => "relation_many",
          "label"      => "Tags",
          "required"   => false,
          "min_items"  => 0,
          "max_items"  => 10,
          "model_id"   => "uuid-of-target-model"   # optional hint for editor UI
        }
      }
  """
  use Okovita.FieldTypes.Base

  import Ecto.Changeset

  @uuid_regex ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

  @impl true
  def primitive_type, do: {:array, :string}

  @impl true
  def cast(nil), do: {:ok, []}
  def cast([]), do: {:ok, []}

  def cast(value) when is_list(value) do
    cleaned =
      value
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn
        id when is_binary(id) -> String.trim(id)
        _ -> nil
      end)
      |> Enum.reject(fn id -> is_nil(id) || id == "" end)

    {:ok, cleaned}
  end

  def cast(_), do: :error

  @impl true
  def validate(changeset, field_name, options) do
    changeset =
      validate_change(changeset, field_name, fn _, ids ->
        invalid = Enum.reject(ids, &Regex.match?(@uuid_regex, &1))

        if invalid == [],
          do: [],
          else: [{field_name, "all items must be valid UUIDs"}]
      end)

    changeset =
      if max = options["max_items"],
        do: validate_length(changeset, field_name, max: max),
        else: changeset

    if min = options["min_items"],
      do: validate_length(changeset, field_name, min: min),
      else: changeset
  end
end
