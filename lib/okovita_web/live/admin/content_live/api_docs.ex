defmodule OkovitaWeb.Admin.ContentLive.ApiDocs do
  @moduledoc "Renders Swagger UI for the dynamic OpenAPI schema."
  use OkovitaWeb, :live_view

  on_mount {OkovitaWeb.LiveAuth, :require_tenant_admin}

  def mount(_params, _session, socket) do
    tenant_slug = socket.assigns.current_tenant.slug
    spec_url = "/admin/tenants/#{tenant_slug}/openapi.json"

    {:ok, assign(socket, spec_url: spec_url)}
  end

  def render(assigns) do
    ~H"""
    <div style="padding: 20px; background: white; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
        <h1>API Explorer</h1>
        <a href={"/admin/tenants/#{@current_tenant.slug}/models"} style="color: #4F46E5; text-decoration: none;">← Back to Models</a>
      </div>

      <div id="swagger-ui-container" phx-update="ignore">
        <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui.css" />
        <div id="swagger-ui"></div>
        <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-bundle.js"></script>
        <script>
          // Wait for custom element or use a simple timeout if we can't hook into LiveView JS easily right now
          setTimeout(function() {
            if (window.SwaggerUIBundle) {
              window.ui = SwaggerUIBundle({
                url: "<%= @spec_url %>",
                dom_id: '#swagger-ui',
                deepLinking: true,
                presets: [
                  SwaggerUIBundle.presets.apis
                ],
                plugins: [
                  SwaggerUIBundle.plugins.DownloadUrl
                ],
                layout: "BaseLayout"
              });
            }
          }, 100);
        </script>
      </div>
    </div>
    """
  end
end
