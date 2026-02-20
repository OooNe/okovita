defmodule OkovitaWeb.Admin.TenantLive.ApiKeys do
  @moduledoc "LiveView for managing a tenant's API keys."
  use OkovitaWeb, :live_view

  alias Okovita.Tenants

  on_mount {OkovitaWeb.LiveAuth, :require_super_admin}

  def mount(%{"tenant_slug" => slug}, _session, socket) do
    case Tenants.get_tenant_by_slug(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Tenant not found")
         |> redirect(to: "/admin/tenants")}

      tenant ->
        api_keys = Tenants.list_api_keys(tenant.id)

        {:ok,
         assign(socket,
           tenant: tenant,
           api_keys: api_keys,
           show_generate: false,
           new_raw_key: nil
         )}
    end
  end

  def handle_event("toggle-generate", _params, socket) do
    {:noreply, assign(socket, show_generate: !socket.assigns.show_generate, new_raw_key: nil)}
  end

  def handle_event("generate-key", %{"name" => name}, socket) do
    tenant_id = socket.assigns.tenant.id

    case Tenants.create_api_key(tenant_id, name) do
      {:ok, %{raw_api_key: raw_api_key}} ->
        api_keys = Tenants.list_api_keys(tenant_id)

        {:noreply,
         socket
         |> assign(api_keys: api_keys, show_generate: false, new_raw_key: raw_api_key)
         |> put_flash(:info, "API key created successfully!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create API key")}
    end
  end

  def handle_event("delete-key-" <> key_id, _params, socket) do
    tenant_id = socket.assigns.tenant.id

    case Tenants.delete_api_key(tenant_id, key_id) do
      {:ok, _} ->
        api_keys = Tenants.list_api_keys(tenant_id)

        {:noreply,
         socket
         |> assign(api_keys: api_keys, new_raw_key: nil)
         |> put_flash(:info, "API key deleted!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete API key")}
    end
  end

  def render(assigns) do
    ~H"""
    <div style="max-width: 1000px; margin: 40px auto; padding: 20px;">
      <a href="/admin/tenants" style="color: #6B7280; text-decoration: none; font-size: 14px; margin-bottom: 12px; display: inline-block;">&larr; Back to Tenants</a>
      <h1>API Keys: <%= @tenant.name %></h1>
      <p style="color: #4B5563; margin-bottom: 24px;">Manage authentication key permissions for this Tenant workspace.</p>

      <%= if @new_raw_key do %>
        <div style="background: #FEF3C7; border: 1px solid #F59E0B; padding: 16px; border-radius: 8px; margin-bottom: 20px;">
          <strong>⚠️ Save this API key — it won't be shown again:</strong>
          <code style="display: block; margin-top: 8px; padding: 12px; background: white; border-radius: 4px; font-size: 16px; user-select: all;"><%= @new_raw_key %></code>
        </div>
      <% end %>

      <button phx-click="toggle-generate" style="margin-bottom: 20px; padding: 8px 16px; background: #4F46E5; color: white; border: none; border-radius: 4px; cursor: pointer;">
        <%= if @show_generate, do: "Cancel", else: "+ Generate Key" %>
      </button>

      <%= if @show_generate do %>
        <form phx-submit="generate-key" style="margin-bottom: 24px; padding: 16px; border: 1px solid #ddd; border-radius: 8px; background: #F9FAFB;">
          <div style="margin-bottom: 12px;">
            <label style="display: block; font-weight: 600; margin-bottom: 4px;">Key Name (e.g., 'Mobile App', 'Staging')</label>
            <input type="text" name="name" required style="width: 100%; max-width: 400px; padding: 8px; border: 1px solid #ccc; border-radius: 4px;" />
          </div>
          <button type="submit" style="padding: 8px 16px; background: #059669; color: white; border: none; border-radius: 4px; cursor: pointer;">Generate Key</button>
        </form>
      <% end %>

      <table style="width: 100%; border-collapse: collapse;">
        <thead>
          <tr style="border-bottom: 2px solid #ddd;">
            <th style="text-align: left; padding: 8px;">Name</th>
            <th style="text-align: left; padding: 8px;">Created At (UTC)</th>
            <th style="text-align: right; padding: 8px;">Actions</th>
          </tr>
        </thead>
        <tbody>
          <%= if length(@api_keys) == 0 do %>
            <tr>
              <td colspan="3" style="padding: 16px; text-align: center; color: #6B7280; font-style: italic;">
                No API keys found. This tenant currently has no access to the API.
              </td>
            </tr>
          <% else %>
            <%= for key <- @api_keys do %>
              <tr style="border-bottom: 1px solid #eee;">
                <td style="padding: 8px; font-weight: 500;"><%= key.name %></td>
                <td style="padding: 8px; color: #4B5563;"><%= format_date(key.inserted_at) %></td>
                <td style="padding: 8px; text-align: right;">
                  <button phx-click={"delete-key-#{key.id}"} data-confirm="Are you sure? This action is immediate and irrevocable, and systems relying on this key will lose access." style="padding: 4px 8px; background: #EF4444; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 12px; margin-left: 4px;">Revoke Key</button>
                </td>
              </tr>
            <% end %>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp format_date(dt) do
    "#{dt.year}-#{pad(dt.month)}-#{pad(dt.day)} #{pad(dt.hour)}:#{pad(dt.minute)}"
  end

  defp pad(num) when num < 10, do: "0#{num}"
  defp pad(num), do: to_string(num)
end
