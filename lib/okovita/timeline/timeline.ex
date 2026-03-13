defmodule Okovita.Timeline do
  @moduledoc """
  Context for timeline/audit operations.
  """

  alias Ecto.Multi
  alias Okovita.Timeline.Record

  import Ecto.Query

  @doc """
  Deeply converts maps and structs into string-keyed maps suitable for JSON/audit encoding.
  Handles known scalar structs (DateTime, NaiveDateTime, Date, Decimal) by passing them through,
  converts other structs to plain maps, and recurses into maps and lists.
  """
  @spec encode_for_audit(any()) :: any()
  def encode_for_audit(data) when is_map(data) do
    map =
      case data do
        %{__struct__: struct} when struct in [DateTime, NaiveDateTime, Date, Decimal] ->
          data

        %{__struct__: _} ->
          data |> Map.from_struct() |> Map.delete(:__meta__)

        _ ->
          data
      end

    if is_struct(map) do
      map
    else
      Enum.into(map, %{}, fn
        {key, value} when is_atom(key) -> {Atom.to_string(key), encode_for_audit(value)}
        {key, value} -> {key, encode_for_audit(value)}
      end)
    end
  end

  def encode_for_audit(list) when is_list(list), do: Enum.map(list, &encode_for_audit/1)
  def encode_for_audit(other), do: other

  @doc """
  Appends a timeline insertion operation to an Ecto.Multi structure.

  ## Parameters
    * `multi` - The Ecto.Multi structure to append to.
    * `name` - The name of the multi operation (e.g., `:timeline`).
    * `entity_type` - The string representing what's being audited (e.g., "model", "entry").
    * `action` - The string representing the action (e.g., "create", "update", "delete").
    * `actor_id` - ID of the user performing the action (optional).
    * `entity_mapper_fn` - A function `(%{deps} -> {entity_id, before_data, after_data})` that extracts audit data from previous Ecto.Multi steps.
    * `opts` - Keyword list options containing `prefix` (mandatory for tenant contexts).
  """
  @spec insert_audit(
          Multi.t(),
          atom(),
          String.t(),
          String.t(),
          binary() | nil,
          (map() -> {binary(), map() | nil, map() | nil}),
          keyword()
        ) :: Multi.t()
  def insert_audit(
        multi,
        name \\ :timeline,
        entity_type,
        action,
        actor_id,
        entity_mapper_fn,
        opts
      ) do
    prefix = Keyword.fetch!(opts, :prefix)

    Multi.insert(
      multi,
      name,
      fn deps ->
        {entity_id, before_data, after_data} = entity_mapper_fn.(deps)

        %Record{}
        |> Ecto.Changeset.change(%{
          entity_id: entity_id,
          entity_type: entity_type,
          action: action,
          actor_id: actor_id,
          before: encode_for_audit(before_data),
          after: encode_for_audit(after_data)
        })
      end,
      prefix: prefix
    )
  end

  @doc "Inserts a timeline record directly."
  def create_record(attrs, prefix) do
    %Record{}
    |> Ecto.Changeset.change(attrs)
    |> Okovita.Repo.insert(prefix: prefix)
  end

  @doc "Lists timeline records for an entity."
  def list_records(entity_id, entity_type, prefix) do
    records =
      from(r in Record,
        where: r.entity_id == ^entity_id and r.entity_type == ^entity_type,
        order_by: [desc: r.inserted_at]
      )
      |> Okovita.Repo.all(prefix: prefix)

    actor_ids = records |> Enum.map(& &1.actor_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    admins_map =
      if actor_ids == [] do
        %{}
      else
        from(a in Okovita.Auth.Admin, where: a.id in ^actor_ids, select: {a.id, a.email})
        |> Okovita.Repo.all()
        |> Enum.into(%{})
      end

    Enum.map(records, fn record ->
      if record.actor_id do
        %{record | actor_email: Map.get(admins_map, record.actor_id)}
      else
        record
      end
    end)
  end
end
