defmodule OkovitaWeb.Transports.REST.Controllers.TenantController do
  @moduledoc "REST controller for tenant management (super admin)."
  use OkovitaWeb, :controller

  alias Okovita.Tenants

  def index(conn, _params) do
    tenants = Tenants.list_tenants()
    json(conn, %{data: Enum.map(tenants, &tenant_json/1)})
  end

  def show(conn, %{"id" => id}) do
    case Tenants.get_tenant(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Tenant not found"}})

      tenant ->
        json(conn, %{data: tenant_json(tenant)})
    end
  end

  def create(conn, params) do
    attrs = %{
      name: params["name"],
      slug: params["slug"]
    }

    case Tenants.create_tenant(attrs) do
      {:ok, %{tenant: tenant, raw_api_key: raw_api_key}} ->
        conn
        |> put_status(:created)
        |> json(%{
          data: Map.put(tenant_json(tenant), :api_key, raw_api_key)
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{message: "Validation failed", details: format_errors(changeset)}})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{message: inspect(reason)}})
    end
  end

  def suspend(conn, %{"id" => id}) do
    case Tenants.get_tenant(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Tenant not found"}})

      tenant ->
        case Tenants.suspend_tenant(tenant) do
          {:ok, tenant} ->
            json(conn, %{data: tenant_json(tenant)})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: %{message: "Suspension failed", details: format_errors(changeset)}})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Tenants.get_tenant(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Tenant not found"}})

      tenant ->
        case Tenants.delete_tenant(tenant) do
          {:ok, _tenant} ->
            send_resp(conn, :no_content, "")

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: %{message: "Deletion failed", details: format_errors(changeset)}})
        end
    end
  end

  defp tenant_json(tenant) do
    %{
      id: tenant.id,
      name: tenant.name,
      slug: tenant.slug,
      status: tenant.status,
      inserted_at: tenant.inserted_at,
      updated_at: tenant.updated_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
