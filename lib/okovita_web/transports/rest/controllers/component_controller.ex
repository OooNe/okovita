defmodule OkovitaWeb.Transports.REST.Controllers.ComponentController do
  @moduledoc "API Controller for fetching component (singleton) mappings."
  use OkovitaWeb, :controller

  alias Okovita.Content

  action_fallback OkovitaWeb.FallbackController

  def show(conn, %{"slug" => slug} = params) do
    prefix = conn.assigns.tenant_prefix
    opts = parse_params(params)
    with_metadata = opts[:with_metadata]

    with model when not is_nil(model) <- Content.get_model_by_slug(slug, prefix),
         true <- model.is_component,
         [entry | _] <- Content.list_entries(model.id, prefix),
         true <- !model.publishable or entry.published_at != nil do
      populated_entry =
        entry
        |> Content.populate(model, prefix, opts)

      json(conn, Okovita.Content.EntryFormatter.format(populated_entry, model, with_metadata))
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Not found"}})

      false ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Not a component model"}})

      [] ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Entry not found"}})
    end
  end

  def update(conn, %{"slug" => slug} = params) do
    prefix = conn.assigns.tenant_prefix
    opts = parse_params(params)
    with_metadata = opts[:with_metadata]

    with model when not is_nil(model) <- Content.get_model_by_slug(slug, prefix),
         true <- model.is_component,
         [entry | _] <- Content.list_entries(model.id, prefix) do
      update_attrs =
        %{}
        |> maybe_put(:slug, params["slug"])
        |> maybe_put(:data, params["data"])

      case Content.update_entry(entry.id, model.id, update_attrs, prefix) do
        {:ok, updated_entry} ->
          populated_entry =
            updated_entry
            |> Content.populate(model, prefix, opts)

          json(conn, Okovita.Content.EntryFormatter.format(populated_entry, model, with_metadata))

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

      false ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Not a component model"}})

      [] ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Entry not found"}})
    end
  end

  # --- Privates for parsing/formatting (copied from EntryController) ---

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
