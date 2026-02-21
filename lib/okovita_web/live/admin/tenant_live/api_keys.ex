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
    <div class="max-w-6xl mx-auto py-8 px-4 sm:px-6 lg:px-8 space-y-6">
      <div>
        <a href="/admin/tenants" class="text-indigo-600 hover:text-indigo-900 text-sm font-medium mb-4 inline-block transition-colors">&larr; Back to Tenants</a>
        <h1 class="text-2xl font-bold text-gray-900">API Keys: <span class="text-indigo-600"><%= @tenant.name %></span></h1>
        <p class="mt-2 text-sm text-gray-500">Manage authentication key permissions for this Tenant workspace.</p>
      </div>

      <%= if @new_raw_key do %>
        <div class="rounded-md bg-yellow-50 p-4 border border-yellow-400">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-yellow-800">Save this API key — it won't be shown again:</h3>
              <div class="mt-2 text-sm text-yellow-700">
                <code class="block font-mono bg-white px-3 py-2 rounded-md border border-yellow-200 select-all"><%= @new_raw_key %></code>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <div>
        <button phx-click="toggle-generate" class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 transition-colors">
          <%= if @show_generate, do: "Cancel", else: "+ Generate Key" %>
        </button>
      </div>

      <%= if @show_generate do %>
        <div class="bg-gray-50 px-6 py-5 border border-gray-200 shadow-sm sm:rounded-lg mb-6">
          <form phx-submit="generate-key" class="space-y-4 max-w-sm">
            <div>
              <label class="block text-sm font-medium text-gray-700">Key Name (e.g., 'Mobile App', 'Staging')</label>
              <div class="mt-1">
                <input type="text" name="name" required class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
              </div>
            </div>
            <div>
              <button type="submit" class="inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 transition-colors">Generate Key</button>
            </div>
          </form>
        </div>
      <% end %>

      <div class="overflow-hidden bg-white ring-1 ring-gray-200 shadow-sm sm:rounded-lg">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">Name</th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Created At (UTC)</th>
              <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6 text-right text-sm font-semibold text-gray-900">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 bg-white">
            <%= if length(@api_keys) == 0 do %>
              <tr>
                <td colspan="3" class="whitespace-nowrap py-8 pl-4 pr-3 text-sm text-center text-gray-500 italic sm:pl-6">
                  No API keys found. This tenant currently has no access to the API.
                </td>
              </tr>
            <% else %>
              <%= for key <- @api_keys do %>
                <tr class="hover:bg-gray-50 transition-colors group">
                  <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6"><%= key.name %></td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500 font-mono"><%= format_date(key.inserted_at) %></td>
                  <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                    <button phx-click={"delete-key-#{key.id}"} data-confirm="Are you sure? This action is immediate and irrevocable, and systems relying on this key will lose access." class="text-red-500 hover:text-red-700 transition-colors focus:outline-none">Revoke Key</button>
                  </td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp format_date(dt) do
    "#{dt.year}-#{pad(dt.month)}-#{pad(dt.day)} #{pad(dt.hour)}:#{pad(dt.minute)}"
  end

  defp pad(num) when num < 10, do: "0#{num}"
  defp pad(num), do: to_string(num)
end
