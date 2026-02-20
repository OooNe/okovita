defmodule OkovitaWeb.Admin.TenantLive.Index do
  @moduledoc "Super admin: list and manage tenants."
  use OkovitaWeb, :live_view

  alias Okovita.Tenants

  on_mount {OkovitaWeb.LiveAuth, :require_super_admin}

  def mount(_params, _session, socket) do
    tenants = Tenants.list_tenants()
    {:ok, assign(socket, tenants: tenants, show_create: false, raw_api_key: nil)}
  end

  def handle_event("toggle-create", _params, socket) do
    {:noreply, assign(socket, show_create: !socket.assigns.show_create, raw_api_key: nil)}
  end

  def handle_event("create-tenant", %{"name" => name, "slug" => slug}, socket) do
    case Tenants.create_tenant(%{name: name, slug: slug}) do
      {:ok, %{raw_api_key: raw_api_key}} ->
        tenants = Tenants.list_tenants()

        {:noreply,
         socket
         |> assign(tenants: tenants, show_create: false, raw_api_key: raw_api_key)
         |> put_flash(:info, "Tenant created!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create tenant")}
    end
  end

  def handle_event("suspend-" <> id, _params, socket) do
    case Tenants.get_tenant(id) do
      nil ->
        {:noreply, socket}

      tenant ->
        Tenants.suspend_tenant(tenant)
        {:noreply, assign(socket, tenants: Tenants.list_tenants())}
    end
  end

  def handle_event("delete-" <> id, _params, socket) do
    case Tenants.get_tenant(id) do
      nil ->
        {:noreply, socket}

      tenant ->
        Tenants.delete_tenant(tenant)
        {:noreply, assign(socket, tenants: Tenants.list_tenants())}
    end
  end

  def render(assigns) do
    ~H"""
    <div style="max-width: 1000px; margin: 40px auto; padding: 20px;">
      <h1>Tenants</h1>

      <%= if @raw_api_key do %>
        <div style="background: #FEF3C7; border: 1px solid #F59E0B; padding: 16px; border-radius: 8px; margin-bottom: 20px;">
          <strong>⚠️ Save this API key — it won't be shown again:</strong>
          <code style="display: block; margin-top: 8px; padding: 8px; background: white; border-radius: 4px; font-size: 14px;"><%= @raw_api_key %></code>
        </div>
      <% end %>

      <button phx-click="toggle-create" style="margin-bottom: 20px; padding: 8px 16px; background: #4F46E5; color: white; border: none; border-radius: 4px; cursor: pointer;">
        <%= if @show_create, do: "Cancel", else: "+ New Tenant" %>
      </button>

      <%= if @show_create do %>
        <form phx-submit="create-tenant" style="margin-bottom: 20px; padding: 16px; border: 1px solid #ddd; border-radius: 8px;">
          <div style="margin-bottom: 12px;">
            <label style="display: block; font-weight: 600;">Name</label>
            <input type="text" name="name" required style="width: 100%; padding: 8px; border: 1px solid #ccc; border-radius: 4px;" />
          </div>
          <div style="margin-bottom: 12px;">
            <label style="display: block; font-weight: 600;">Slug</label>
            <input type="text" name="slug" required pattern="[a-z0-9-]+" style="width: 100%; padding: 8px; border: 1px solid #ccc; border-radius: 4px;" />
          </div>
          <button type="submit" style="padding: 8px 16px; background: #059669; color: white; border: none; border-radius: 4px; cursor: pointer;">Create</button>
        </form>
      <% end %>

      <table style="width: 100%; border-collapse: collapse;">
        <thead>
          <tr style="border-bottom: 2px solid #ddd;">
            <th style="text-align: left; padding: 8px;">Name</th>
            <th style="text-align: left; padding: 8px;">Slug</th>
            <th style="text-align: left; padding: 8px;">Status</th>
            <th style="text-align: right; padding: 8px;">Actions</th>
          </tr>
        </thead>
        <tbody>
          <%= for tenant <- @tenants do %>
            <tr style="border-bottom: 1px solid #eee;">
              <td style="padding: 8px;"><%= tenant.name %></td>
              <td style="padding: 8px;"><code><%= tenant.slug %></code></td>
              <td style="padding: 8px;">
                <span style={"padding: 2px 8px; border-radius: 12px; font-size: 12px; #{status_color(tenant.status)}"}>
                  <%= tenant.status %>
                </span>
              </td>
              <td style="padding: 8px; text-align: right;">
                <%= if tenant.status == :active do %>
                  <button phx-click={"suspend-#{tenant.id}"} data-confirm="Are you sure you want to suspend this tenant?" style="padding: 4px 8px; background: #F59E0B; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 12px;">Suspend</button>
                  <a href={"/admin/tenants/#{tenant.slug}/api-keys"} style="padding: 4px 8px; background: #6366F1; color: white; border: none; border-radius: 4px; text-decoration: none; font-size: 12px; margin-left: 4px;">Manage Keys</a>
                  <a href={"/admin/tenants/#{tenant.slug}/models"} style="padding: 4px 8px; background: #3B82F6; color: white; border: none; border-radius: 4px; text-decoration: none; font-size: 12px; margin-left: 4px;">Manage Content</a>
                <% end %>
                <button phx-click={"delete-#{tenant.id}"} data-confirm="Are you sure you want to delete this tenant?" style="padding: 4px 8px; background: #EF4444; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 12px; margin-left: 4px;">Delete</button>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp status_color(:active), do: "background: #D1FAE5; color: #065F46;"
  defp status_color(:suspended), do: "background: #FEF3C7; color: #92400E;"
  defp status_color(_), do: "background: #F3F4F6; color: #374151;"
end
