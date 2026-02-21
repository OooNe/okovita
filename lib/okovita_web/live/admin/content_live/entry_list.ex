defmodule OkovitaWeb.Admin.ContentLive.EntryList do
  @moduledoc "Tenant admin: list entries for a content model."
  use OkovitaWeb, :live_view

  alias Okovita.Content

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
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-3">
          <h1 class="text-2xl font-bold text-gray-900">Entries: <%= @model.name %></h1>
        </div>
        <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{@model.slug}/entries/new"} class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 transition-colors">
          + New Entry
        </a>
      </div>

      <div class="overflow-hidden bg-white ring-1 ring-gray-200 shadow-sm sm:rounded-lg">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">Slug</th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Created</th>
              <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6 text-right text-sm font-semibold text-gray-900">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 bg-white">
            <%= for entry <- @entries do %>
              <tr class="hover:bg-gray-50 transition-colors group">
                <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6"><%= entry.slug %></td>
                <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= Calendar.strftime(entry.inserted_at, "%Y-%m-%d %H:%M") %></td>
                <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6 space-x-3">
                  <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{@model.slug}/entries/#{entry.id}/edit"} class="text-indigo-600 hover:text-indigo-900">Edit</a>
                  <a href={"/admin/tenants/#{@current_tenant.slug}/timeline/entry/#{entry.id}"} class="text-gray-500 hover:text-gray-900">History</a>
                  <button phx-click={"delete-#{entry.id}"} class="text-red-600 hover:text-red-900 font-medium">Delete</button>
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
