defmodule OkovitaWeb.Admin.ContentLive.EntryList do
  @moduledoc "Tenant admin: list entries for a content model."
  use OkovitaWeb, :live_view

  alias Okovita.Content

  on_mount {OkovitaWeb.LiveAuth, :require_tenant_admin}

  def mount(%{"model_slug" => slug}, _session, socket) do
    prefix = socket.assigns.tenant_prefix
    model = Content.get_model_by_slug(slug, prefix)

    if model do
      entries = Content.list_entries(model.id, prefix)
      {:ok, assign(socket, model: model, entries: entries, prefix: prefix)}
    else
      {:ok, push_navigate(socket, to: "/admin/models")}
    end
  end

  def handle_event("delete-" <> entry_id, _params, socket) do
    Content.delete_entry(entry_id, socket.assigns.prefix)
    entries = Content.list_entries(socket.assigns.model.id, socket.assigns.prefix)
    {:noreply, assign(socket, entries: entries)}
  end

  def render(assigns) do
    ~H"""
    <div style="max-width: 900px; margin: 40px auto; padding: 20px;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
        <h1>Entries: <%= @model.name %></h1>
        <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{@model.slug}/entries/new"} style="padding: 8px 16px; background: #4F46E5; color: white; border: none; border-radius: 4px; text-decoration: none;">
          + New Entry
        </a>
      </div>

      <table style="width: 100%; border-collapse: collapse;">
        <thead>
          <tr style="border-bottom: 2px solid #ddd;">
            <th style="text-align: left; padding: 8px;">Slug</th>
            <th style="text-align: left; padding: 8px;">Created</th>
            <th style="text-align: right; padding: 8px;">Actions</th>
          </tr>
        </thead>
        <tbody>
          <%= for entry <- @entries do %>
            <tr style="border-bottom: 1px solid #eee;">
              <td style="padding: 8px;"><%= entry.slug %></td>
              <td style="padding: 8px;"><%= Calendar.strftime(entry.inserted_at, "%Y-%m-%d %H:%M") %></td>
              <td style="padding: 8px; text-align: right;">
                <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{@model.slug}/entries/#{entry.id}/edit"} style="color: #4F46E5; margin-right: 8px;">Edit</a>
                <a href={"/admin/tenants/#{@current_tenant.slug}/timeline/entry/#{entry.id}"} style="color: #6B7280; margin-right: 8px;">History</a>
                <button phx-click={"delete-#{entry.id}"} style="padding: 4px 8px; background: #EF4444; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 12px;">Delete</button>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>

      <a href={"/admin/tenants/#{@current_tenant.slug}/models"} style="display: inline-block; margin-top: 20px; color: #4F46E5;">← Back to Models</a>
    </div>
    """
  end
end
