defmodule OkovitaWeb.Admin.ContentLive.ModelList do
  @moduledoc "Tenant admin: list content models."
  use OkovitaWeb, :live_view

  alias Okovita.Content

  def mount(_params, _session, socket) do
    prefix = socket.assigns.tenant_prefix
    models = Content.list_models(prefix)
    {:ok, assign(socket, models: models)}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold text-gray-900">Content Models</h1>
        <div class="flex items-center space-x-4">
          <a href={"/admin/tenants/#{@current_tenant.slug}/models/new"} class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 transition-colors">
            + New Model
          </a>
        </div>
      </div>

      <div class="overflow-hidden bg-white ring-1 ring-gray-200 shadow-sm sm:rounded-lg">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">Name</th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Slug</th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Fields</th>
              <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6 text-right text-sm font-semibold text-gray-900">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 bg-white">
            <%= for model <- @models do %>
              <tr class="hover:bg-gray-50 transition-colors group">
                <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6"><%= model.name %></td>
                <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500 font-mono"><%= model.slug %></td>
                <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= map_size(model.schema_definition) %> fields</td>
                <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6 space-x-3">
                  <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{model.slug}/entries"} class="text-indigo-600 hover:text-indigo-900">Entries</a>
                  <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{model.id}/edit"} class="text-gray-500 hover:text-gray-900">Edit</a>
                  <a href={"/admin/tenants/#{@current_tenant.slug}/timeline/model/#{model.id}"} class="text-gray-500 hover:text-gray-900">History</a>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
