defmodule OkovitaWeb.Admin.TenantLive.Index do
  @moduledoc "Super admin: list and manage tenants."
  use OkovitaWeb, :live_view

  alias Okovita.Tenants

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
    <div class="max-w-6xl mx-auto py-8 px-4 sm:px-6 lg:px-8 space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold text-gray-900">Tenants</h1>
        <button phx-click="toggle-create" class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 transition-colors">
          <%= if @show_create, do: "Cancel", else: "+ New Tenant" %>
        </button>
      </div>

      <%= if @raw_api_key do %>
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
                <code class="block font-mono bg-white px-3 py-2 rounded-md border border-yellow-200"><%= @raw_api_key %></code>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @show_create do %>
        <div class="bg-white px-6 py-5 border-b border-gray-200 sm:px-6 shadow sm:rounded-lg">
          <form phx-submit="create-tenant" class="space-y-4 max-w-sm">
            <div>
              <label class="block text-sm font-medium text-gray-700">Name</label>
              <div class="mt-1">
                <input type="text" name="name" required class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Slug</label>
              <div class="mt-1">
                <input type="text" name="slug" required pattern="[a-z0-9-]+" class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm font-mono" />
              </div>
            </div>
            <div>
              <button type="submit" class="inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 transition-colors">Create</button>
            </div>
          </form>
        </div>
      <% end %>

      <div class="overflow-hidden bg-white ring-1 ring-gray-200 shadow-sm sm:rounded-lg">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">Name</th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Slug</th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Status</th>
              <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6 text-right text-sm font-semibold text-gray-900">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 bg-white">
            <%= for tenant <- @tenants do %>
              <tr class="hover:bg-gray-50 transition-colors group">
                <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6"><%= tenant.name %></td>
                <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500 font-mono"><%= tenant.slug %></td>
                <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                  <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{status_color(tenant.status)}"}>
                    <%= tenant.status %>
                  </span>
                </td>
                <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6 space-x-2">
                  <%= if tenant.status == :active do %>
                    <button phx-click={"suspend-#{tenant.id}"} data-confirm="Are you sure you want to suspend this tenant?" class="text-yellow-600 hover:text-yellow-900 transition-colors">Suspend</button>
                    <a href={"/admin/tenants/#{tenant.slug}/api-keys"} class="text-indigo-600 hover:text-indigo-900 transition-colors pl-2 border-l border-gray-300">Keys</a>
                    <a href={"/admin/tenants/#{tenant.slug}/models"} class="text-blue-600 hover:text-blue-900 transition-colors pl-2 border-l border-gray-300">Content</a>
                  <% end %>
                  <button phx-click={"delete-#{tenant.id}"} data-confirm="Are you sure you want to delete this tenant?" class="text-red-500 hover:text-red-700 transition-colors pl-2 border-l border-red-200">Delete</button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp status_color(:active), do: "bg-green-100 text-green-800"
  defp status_color(:suspended), do: "bg-yellow-100 text-yellow-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"
end
