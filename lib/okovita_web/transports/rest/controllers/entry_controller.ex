defmodule OkovitaWeb.Transports.REST.Controllers.EntryController do
  @moduledoc "REST controller for content entries."
  use OkovitaWeb, :controller

  alias Okovita.Content.EntryFormatter
  alias Okovita.Content

  action_fallback OkovitaWeb.FallbackController

  def index(conn, %{"model_slug" => model_slug} = params) do
    prefix = conn.assigns.tenant_prefix
    opts = parse_params(params)
    with_metadata = opts[:with_metadata]

    case Content.get_model_by_slug(model_slug, prefix) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Model not found"}})

      model ->
        entries = Content.list_entries(model.id, prefix)

        populated_entries =
          entries
          |> Content.populate(model, prefix, opts)

        json(conn, Enum.map(populated_entries, &EntryFormatter.format(&1, model, with_metadata)))
    end
  end

  def show(conn, %{"model_slug" => model_slug, "id" => id} = params) do
    prefix = conn.assigns.tenant_prefix
    opts = parse_params(params)
    with_metadata = opts[:with_metadata]

    with model when not is_nil(model) <- Content.get_model_by_slug(model_slug, prefix),
         entry when not is_nil(entry) <- Content.get_entry(id, prefix) do
      populated_entry =
        entry
        |> Content.populate(model, prefix, opts)

      json(conn, EntryFormatter.format(populated_entry, model, with_metadata))
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Not found"}})
    end
  end

  def create(conn, %{"model_slug" => model_slug} = params) do
    prefix = conn.assigns.tenant_prefix
    opts = parse_params(params)
    with_metadata = opts[:with_metadata]

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
              |> Content.populate(model, prefix, opts)

            conn
            |> put_status(:created)
            |> json(EntryFormatter.format(populated_entry, model, with_metadata))

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
    opts = parse_params(params)
    with_metadata = opts[:with_metadata]

    with model when not is_nil(model) <- Content.get_model_by_slug(model_slug, prefix) do
      update_attrs =
        %{}
        |> maybe_put(:slug, params["slug"])
        |> maybe_put(:data, params["data"])

      case Content.update_entry(id, model.id, update_attrs, prefix) do
        {:ok, entry} ->
          populated_entry =
            entry
            |> Content.populate(model, prefix, opts)

          json(conn, EntryFormatter.format(populated_entry, model, with_metadata))

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

  def relations(
        conn,
        %{"model_slug" => parent_slug, "id" => parent_id, "child_model_slug" => child_slug} =
          params
      ) do
    prefix = conn.assigns.tenant_prefix
    opts = parse_params(params)
    with_metadata = opts[:with_metadata]

    case Content.list_entries_by_parent(parent_id, parent_slug, child_slug, prefix) do
      {child_model, entries} ->
        populated_entries =
          entries
          |> Content.populate(child_model, prefix, opts)

        json(
          conn,
          Enum.map(populated_entries, &EntryFormatter.format(&1, child_model, with_metadata))
        )

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Parent entry or model not found"}})
    end
  end

  defp parse_params(params) do
    [
      with_metadata: parse_boolean(params["withMetadata"], false),
      populate: parse_populate(params["populate"])
    ]
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

  defp parse_populate(nil), do: []
  defp parse_populate("*"), do: :all

  defp parse_populate(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
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
