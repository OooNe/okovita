defmodule OkovitaWeb.Transports.REST.Controllers.OpenAPIController do
  @moduledoc "REST controller for dynamic OpenAPI schema."
  use OkovitaWeb, :controller

  alias Okovita.Content
  alias Okovita.OpenAPI.Generator

  def show(conn, _params) do
    tenant = conn.assigns.tenant
    prefix = conn.assigns.tenant_prefix

    models = Content.list_models(prefix)
    spec = Generator.generate(tenant, models)

    json(conn, spec)
  end
end
