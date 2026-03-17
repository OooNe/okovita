defmodule OkovitaWeb.Transports.REST.Controllers.PublicOpenAPIController do
  @moduledoc "Public endpoint serving OpenAPI spec per tenant (no auth required)."
  use OkovitaWeb, :controller

  alias Okovita.Content
  alias Okovita.OpenAPI.Generator
  alias Okovita.Tenants

  def show(conn, %{"tenant_slug" => tenant_slug}) do
    case Tenants.get_tenant_by_slug(tenant_slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: [%{message: "Tenant not found"}]})

      tenant ->
        prefix = Tenants.tenant_prefix(tenant)
        models = Content.list_models(prefix)
        spec = Generator.generate(tenant, models)
        json(conn, spec)
    end
  end
end
