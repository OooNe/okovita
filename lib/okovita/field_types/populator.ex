defmodule Okovita.FieldTypes.Populator do
  @moduledoc """
  Behaviour for field type populators.

  Populators are optional sub-modules (e.g., `Okovita.FieldTypes.Image.Populator`)
  responsible for extracting database references and substituting fetched entities
  back into the field's data structure.
  """

  @doc """
  Returns the target repository domain for population (`:entry` or `:media`),
  or `nil` if the type does not support database population.
  """
  @callback population_target() :: atom() | nil

  @doc """
  Extracts a list of UUID references from the field's raw value, used to query the database.
  """
  @callback extract_references(value :: any()) :: [String.t()]

  @doc """
  Populates the field's value using the fetched entities map.
  `opts` can include information like `populate: ["relation_name"]`.
  """
  @callback populate(value :: any(), entities :: map(), opts :: map()) :: any()

  @doc """
  Builds an Ecto dynamic query to perform a reverse lookup using JSONB operators.
  Used by Entries.Queries to find parent references embedded in JSONB relation fields.
  """
  @callback reverse_lookup_query(
              key :: String.t(),
              parent_id :: String.t(),
              acc :: Ecto.Query.dynamic()
            ) :: Ecto.Query.dynamic()

  @optional_callbacks [reverse_lookup_query: 3]
end
