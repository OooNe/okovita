defmodule OkovitaWeb.Admin.OpenAPIController do
  @moduledoc "Admin controller for serving dynamic OpenAPI specs per tenant."
  use OkovitaWeb, :controller

  alias Okovita.Content
  alias Okovita.Tenants
  alias Okovita.OpenAPI.Generator

  def show(conn, %{"tenant_slug" => tenant_slug}) do
    admin = conn.assigns.current_admin

    if can_access_tenant?(admin, tenant_slug) do
      tenant = Tenants.get_tenant_by_slug(tenant_slug)

      if tenant do
        prefix = "tenant_#{tenant.id}"
        models = Content.list_models(prefix)
        spec = Generator.generate(tenant, models)
        json(conn, spec)
      else
        conn |> put_status(:not_found) |> json(%{error: "Tenant not found"})
      end
    else
      conn |> put_status(:unauthorized) |> json(%{error: "Unauthorized"})
    end
  end

  defp can_access_tenant?(%{role: :super_admin}, _slug), do: true

  defp can_access_tenant?(%{role: :tenant_admin, tenant_id: tenant_id}, slug) do
    tenant = Tenants.get_tenant(tenant_id)
    tenant && tenant.slug == slug
  end
end
