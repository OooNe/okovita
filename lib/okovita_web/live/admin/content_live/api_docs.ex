defmodule OkovitaWeb.Admin.ContentLive.ApiDocs do
  @moduledoc "Renders Swagger UI for the dynamic OpenAPI schema."
  use OkovitaWeb, :live_view

  def mount(_params, _session, socket) do
    tenant_slug = socket.assigns.current_tenant.slug
    spec_url = "/admin/tenants/#{tenant_slug}/openapi.json"

    {:ok, assign(socket, spec_url: spec_url)}
  end

  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold text-gray-900">API Explorer</h1>
        <a href={"/admin/tenants/#{@current_tenant.slug}/models"} class="text-indigo-600 hover:text-indigo-900 font-medium">← Back to Models</a>
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
