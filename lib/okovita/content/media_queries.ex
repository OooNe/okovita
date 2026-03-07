defmodule Okovita.Content.MediaQueries do
  @moduledoc """
  Handles database queries for the Media context.
  """
  import Ecto.Query
  alias Okovita.Content.Media
  alias Okovita.Content.Entry
  alias Okovita.Repo

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

  @doc """
  Checks if a media ID is referenced anywhere in the entries data JSONB column.
  """
  def media_in_use?(media_id, prefix) when is_binary(media_id) do
    query = """
    SELECT EXISTS (
      SELECT 1 FROM "#{prefix}"."content_entries"
      WHERE data::text LIKE $1
    )
    """

    case Ecto.Adapters.SQL.query(Repo, query, ["%#{media_id}%"]) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end

  @doc """
  Deletes a media record by ID within the given tenant prefix.
  """
  def delete_media(media_id, prefix) do
    case get_media!(media_id, prefix) do
      %Media{} = media ->
        # Delete from S3 storage asynchronously or ignore error to proceed with DB delete
        Okovita.Media.Uploader.delete(media.file_name)
        remove_media_references([media_id], prefix)
        Repo.delete(media, prefix: prefix)
    end
  end

  @doc """
  Checks if any of the provided media IDs are referenced anywhere in the entries data JSONB column.
  """
  def any_media_in_use?(media_ids, prefix) when is_list(media_ids) do
    if Enum.empty?(media_ids) do
      false
    else
      # Build dynamic LIKE conditions for each UUID
      # SQLite and Postgres handle variable argument binding slightly differently, falling back to positional syntax for Postgres mapping in plain SQL: $1, $2, $3...
      positions = Enum.map_join(1..length(media_ids), " OR ", fn i -> "data::text LIKE $#{i}" end)
      params = Enum.map(media_ids, fn id -> "%#{id}%" end)

      query = """
      SELECT EXISTS (
        SELECT 1 FROM "#{prefix}"."content_entries"
        WHERE #{positions}
      )
      """

      case Ecto.Adapters.SQL.query(Repo, query, params) do
        {:ok, %{rows: [[true]]}} -> true
        _ -> false
      end
    end
  end

  @doc """
  Deletes multiple media records by their IDs within the given tenant prefix.
  """
  def delete_all_media(media_ids, prefix) when is_list(media_ids) do
    if Enum.empty?(media_ids) do
      {0, nil}
    else
      # Fetch all media files first to get their file names
      medias = Repo.all(from(m in Media, where: m.id in ^media_ids), prefix: prefix)

      # Clean up from storage
      Enum.each(medias, fn media ->
        Okovita.Media.Uploader.delete(media.file_name)
      end)

      remove_media_references(media_ids, prefix)
      Repo.delete_all(from(m in Media, where: m.id in ^media_ids), prefix: prefix)
    end
  end

  # Scans all entries for matching media IDs and unsets them from JSON `data` payloads
  defp remove_media_references(media_ids, prefix) do
    if any_media_in_use?(media_ids, prefix) do
      # Fetch all entries to scan and update. Since JSONB schema is dynamic,
      # Elixir parsing is safer than complex JSONB recursive arrays update queries.
      entries = Repo.all(from(e in Entry), prefix: prefix)

      Enum.each(entries, fn entry ->
        new_data = reject_media_ids_from_data(entry.data, media_ids)

        if new_data != entry.data do
          entry
          |> Ecto.Changeset.change(%{data: new_data})
          |> Repo.update!(prefix: prefix)
        end
      end)
    end
  end

  # Returns a new map with the specified media IDs rejected
  defp reject_media_ids_from_data(%{} = data, []) do
    data
  end

  defp reject_media_ids_from_data(%{} = data, ids_to_remove) when is_list(ids_to_remove) do
    Enum.into(data, %{}, fn {k, v} -> {k, reject_value_references(v, ids_to_remove)} end)
  end

  defp reject_media_ids_from_data(data, _), do: data

  defp reject_value_references(v, ids_to_remove) when is_binary(v) do
    if v in ids_to_remove, do: "", else: v
  end

  defp reject_value_references(v, ids_to_remove) when is_list(v) do
    Enum.reject(v, fn
      %{"media_id" => id} -> id in ids_to_remove
      id when is_binary(id) -> id in ids_to_remove
      _ -> false
    end)
  end

  defp reject_value_references(v, _ids_to_remove), do: v
end
