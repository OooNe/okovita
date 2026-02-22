defmodule OkovitaWeb.Transports.REST.Controllers.EntryController do
  @moduledoc "REST controller for content entries."
  use OkovitaWeb, :controller

  alias Okovita.Content

  action_fallback OkovitaWeb.FallbackController

  def index(conn, %{"model_slug" => model_slug} = params) do
    prefix = conn.assigns.tenant_prefix
    with_metadata = parse_boolean(params["withMetadata"], false)

    case Content.get_model_by_slug(model_slug, prefix) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Model not found"}})

      model ->
        entries = Content.list_entries(model.id, prefix)

        populated_entries =
          entries
          |> Content.populate_relations(model, prefix, with_metadata: with_metadata)
          |> Content.populate_media(model, prefix)

        json(conn, Enum.map(populated_entries, &entry_json(&1, with_metadata)))
    end
  end

  def show(conn, %{"model_slug" => model_slug, "id" => id} = params) do
    prefix = conn.assigns.tenant_prefix
    with_metadata = parse_boolean(params["withMetadata"], false)

    with model when not is_nil(model) <- Content.get_model_by_slug(model_slug, prefix),
         entry when not is_nil(entry) <- Content.get_entry(id, prefix) do
      populated_entry =
        entry
        |> Content.populate_relations(model, prefix, with_metadata: with_metadata)
        |> Content.populate_media(model, prefix)

      json(conn, entry_json(populated_entry, with_metadata))
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Not found"}})
    end
  end

  def create(conn, %{"model_slug" => model_slug} = params) do
    prefix = conn.assigns.tenant_prefix
    with_metadata = parse_boolean(params["withMetadata"], false)

    case Content.get_model_by_slug(model_slug, prefix) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Model not found"}})

      model ->
        entry_attrs = %{
          slug: params["slug"],
          data: params["data"] || %{}
        }

        case Content.create_entry(model.id, entry_attrs, prefix) do
          {:ok, entry} ->
            populated_entry =
              entry
              |> Content.populate_relations(model, prefix, with_metadata: with_metadata)
              |> Content.populate_media(model, prefix)

            conn
            |> put_status(:created)
            |> json(entry_json(populated_entry, with_metadata))

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: %{message: "Validation failed", details: format_errors(changeset)}})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: %{message: to_string(reason)}})
        end
    end
  end

  def update(conn, %{"model_slug" => model_slug, "id" => id} = params) do
    prefix = conn.assigns.tenant_prefix
    with_metadata = parse_boolean(params["withMetadata"], false)

    with model when not is_nil(model) <- Content.get_model_by_slug(model_slug, prefix) do
      update_attrs =
        %{}
        |> maybe_put(:slug, params["slug"])
        |> maybe_put(:data, params["data"])

      case Content.update_entry(id, model.id, update_attrs, prefix) do
        {:ok, entry} ->
          populated_entry =
            entry
            |> Content.populate_relations(model, prefix, with_metadata: with_metadata)
            |> Content.populate_media(model, prefix)

          json(conn, entry_json(populated_entry, with_metadata))

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: %{message: "Entry not found"}})

        {:error, %Ecto.Changeset{} = changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: %{message: "Validation failed", details: format_errors(changeset)}})

        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: %{message: to_string(reason)}})
      end
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Model not found"}})
    end
  end

  def delete(conn, %{"id" => id}) do
    prefix = conn.assigns.tenant_prefix

    case Content.delete_entry(id, prefix) do
      {:ok, _entry} ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Entry not found"}})
    end
  end

  defp entry_json(entry, with_metadata) do
    # Check if entry is already structured from a nested population
    if Map.has_key?(entry, :metadata) and Map.has_key?(entry, :data) do
      if with_metadata, do: entry, else: entry.data
    else
      data = Map.put(entry.data || %{}, "id", entry.id)

      if with_metadata do
        %{
          metadata: %{
            slug: entry.slug,
            model_id: entry.model_id,
            inserted_at: entry.inserted_at,
            updated_at: entry.updated_at
          },
          data: data
        }
      else
        data
      end
    end
  end

  defp parse_boolean(value, default) do
    case value do
      "true" -> true
      "1" -> true
      "false" -> false
      "0" -> false
      _ -> default
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
