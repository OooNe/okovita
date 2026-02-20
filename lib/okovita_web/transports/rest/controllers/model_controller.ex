defmodule OkovitaWeb.Transports.REST.Controllers.ModelController do
  @moduledoc "REST controller for content models."
  use OkovitaWeb, :controller

  alias Okovita.Content

  def index(conn, _params) do
    prefix = conn.assigns.tenant_prefix
    models = Content.list_models(prefix)
    json(conn, %{data: Enum.map(models, &model_json/1)})
  end

  def show(conn, %{"id" => id}) do
    prefix = conn.assigns.tenant_prefix

    case Content.get_model(id, prefix) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Model not found"}})

      model ->
        json(conn, %{data: model_json(model)})
    end
  end

  def create(conn, params) do
    prefix = conn.assigns.tenant_prefix

    attrs = %{
      slug: params["slug"],
      name: params["name"],
      schema_definition: params["schema_definition"] || %{}
    }

    case Content.create_model(attrs, prefix) do
      {:ok, model} ->
        conn
        |> put_status(:created)
        |> json(%{data: model_json(model)})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{message: "Validation failed", details: format_errors(changeset)}})
    end
  end

  def update(conn, %{"id" => id} = params) do
    prefix = conn.assigns.tenant_prefix

    attrs =
      %{}
      |> maybe_put(:slug, params["slug"])
      |> maybe_put(:name, params["name"])
      |> maybe_put(:schema_definition, params["schema_definition"])

    case Content.update_model(id, attrs, prefix) do
      {:ok, model} ->
        json(conn, %{data: model_json(model)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Model not found"}})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{message: "Validation failed", details: format_errors(changeset)}})
    end
  end

  defp model_json(model) do
    %{
      id: model.id,
      slug: model.slug,
      name: model.name,
      schema_definition: model.schema_definition,
      inserted_at: model.inserted_at,
      updated_at: model.updated_at
    }
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
