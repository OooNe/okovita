defmodule Okovita.Content.MediaQueries do
  @moduledoc """
  Handles database queries for the Media context.
  """
  import Ecto.Query
  alias Okovita.Repo
  alias Okovita.Content.Media

  @doc """
  Creates a media record within the given tenant prefix.
  """
  def create_media(attrs, prefix) do
    %Media{}
    |> Media.changeset(attrs)
    |> Repo.insert(prefix: prefix)
  end

  @doc """
  Gets a single media record by ID within the given tenant prefix.
  """
  def get_media!(id, prefix) do
    Repo.get!(Media, id, prefix: prefix)
  end

  def get_media(id, _prefix) when is_nil(id), do: nil

  def get_media(id, prefix) do
    Repo.get(Media, id, prefix: prefix)
  end

  @doc """
  Gets multiple media records by their IDs within the given tenant prefix.
  """
  def get_media_by_ids(ids, prefix) do
    valid_ids = Enum.reject(ids, &is_nil/1)

    if valid_ids == [] do
      []
    else
      Repo.all(from(m in Media, where: m.id in ^valid_ids), prefix: prefix)
    end
  end

  @doc """
  Lists all media records within the given tenant prefix, ordered by newest first.
  """
  def list_media(prefix) do
    Repo.all(from(m in Media, order_by: [desc: m.inserted_at]), prefix: prefix)
  end
end
