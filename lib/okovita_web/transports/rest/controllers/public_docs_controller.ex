defmodule OkovitaWeb.Transports.REST.Controllers.PublicDocsController do
  @moduledoc "Public Swagger UI page per tenant — no authentication required."
  use OkovitaWeb, :controller

  alias Okovita.Tenants

  def show(conn, %{"tenant_slug" => tenant_slug}) do
    case Tenants.get_tenant_by_slug(tenant_slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("Tenant not found")

      tenant ->
        spec_url = "/api/v1/tenants/#{tenant_slug}/openapi.json"

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, swagger_html(tenant.name, spec_url))
    end
  end

  defp swagger_html(tenant_name, spec_url) do
    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <title>#{tenant_name} — API Docs</title>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui.css" />
        <style>body { margin: 0; }</style>
      </head>
      <body>
        <div id="swagger-ui"></div>
        <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-bundle.js"></script>
        <script>
          SwaggerUIBundle({
            url: "#{spec_url}",
            dom_id: "#swagger-ui",
            deepLinking: true,
            presets: [SwaggerUIBundle.presets.apis, SwaggerUIBundle.SwaggerUIStandalonePreset],
            layout: "BaseLayout"
          });
        </script>
      </body>
    </html>
    """
  end
end
