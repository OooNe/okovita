defmodule OkovitaWeb.Admin.ContentLive.ModelList do
  @moduledoc "Tenant admin: list content models."
  use OkovitaWeb, :live_view

  alias Okovita.Content

  on_mount {OkovitaWeb.LiveAuth, :require_tenant_admin}

  def mount(_params, _session, socket) do
    prefix = socket.assigns.tenant_prefix
    models = Content.list_models(prefix)
    {:ok, assign(socket, models: models)}
  end

  def render(assigns) do
    ~H"""
    <div style="max-width: 900px; margin: 40px auto; padding: 20px;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
        <h1>Content Models</h1>
        <div>
          <a href={"/admin/tenants/#{@current_tenant.slug}/api-docs"} style="margin-right: 16px; color: #4F46E5; text-decoration: none; font-weight: 500;">
            View API Docs
          </a>
          <a href={"/admin/tenants/#{@current_tenant.slug}/models/new"} style="padding: 8px 16px; background: #4F46E5; color: white; border: none; border-radius: 4px; text-decoration: none;">
            + New Model
          </a>
        </div>
      </div>

      <table style="width: 100%; border-collapse: collapse;">
        <thead>
          <tr style="border-bottom: 2px solid #ddd;">
            <th style="text-align: left; padding: 8px;">Name</th>
            <th style="text-align: left; padding: 8px;">Slug</th>
            <th style="text-align: left; padding: 8px;">Fields</th>
            <th style="text-align: right; padding: 8px;">Actions</th>
          </tr>
        </thead>
        <tbody>
          <%= for model <- @models do %>
            <tr style="border-bottom: 1px solid #eee;">
              <td style="padding: 8px;"><%= model.name %></td>
              <td style="padding: 8px;"><code><%= model.slug %></code></td>
              <td style="padding: 8px;"><%= map_size(model.schema_definition) %> fields</td>
              <td style="padding: 8px; text-align: right;">
                <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{model.slug}/entries"} style="color: #4F46E5; margin-right: 8px;">Entries</a>
                <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{model.id}/edit"} style="color: #6B7280; margin-right: 8px;">Edit</a>
                <a href={"/admin/tenants/#{@current_tenant.slug}/timeline/model/#{model.id}"} style="color: #6B7280;">History</a>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
