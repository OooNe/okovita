defmodule OkovitaWeb.Admin.ContentLive.ModelList do
  @moduledoc "Tenant admin: list content models."
  use OkovitaWeb, :live_view

  alias Okovita.Content

  def mount(_params, _session, socket) do
    prefix = socket.assigns.tenant_prefix
    models = Content.list_models(prefix)
    collections = Enum.filter(models, &(!&1.is_component))
    components = Enum.filter(models, & &1.is_component)

    {:ok,
     assign(socket,
       collections: collections,
       components: components,
       delete_target: nil,
       delete_confirmation: ""
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={:admin}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold text-gray-900">Content Models</h1>
          <div class="flex items-center space-x-4">
            <a href={"/admin/tenants/#{@current_tenant.slug}/models/new"} class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 transition-colors">
              + New Model
            </a>
          </div>
        </div>

        <%= if length(@collections) > 0 do %>
          <div class="mb-4">
            <h2 class="text-lg font-semibold text-gray-900 mb-3">Collections</h2>
            <.model_table models={@collections} current_tenant={@current_tenant} />
          </div>
        <% end %>

        <%= if length(@components) > 0 do %>
          <div>
            <h2 class="text-lg font-semibold text-gray-900 mb-3">Components</h2>
            <.model_table models={@components} current_tenant={@current_tenant} />
          </div>
        <% end %>

        <%= if Enum.empty?(@collections) and Enum.empty?(@components) do %>
          <div class="text-center py-12 bg-white rounded-lg border-2 border-dashed border-gray-300">
            <h3 class="mt-2 text-sm font-semibold text-gray-900">No content models yet</h3>
            <p class="mt-1 text-sm text-gray-500">Get started by creating a new model or component.</p>
          </div>
        <% end %>
      </div>

      <%!-- Delete confirmation modal --%>
      <div :if={@delete_target} class="relative z-50" aria-modal="true">
        <div class="fixed inset-0 bg-gray-500/75 transition-opacity" phx-click="cancel-delete"></div>

        <div class="fixed inset-0 z-10 overflow-y-auto">
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative w-full max-w-md rounded-xl bg-white p-6 shadow-2xl">
              <div class="space-y-4">
                <div class="flex items-center gap-3">
                  <div class="flex h-10 w-10 items-center justify-center rounded-full bg-red-100">
                    <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-600" />
                  </div>
                  <h3 class="text-lg font-semibold text-gray-900">Usuń model</h3>
                </div>

                <p class="text-sm text-gray-600">
                  Ta operacja usunie model <strong class="text-gray-900"><%= @delete_target.name %></strong>
                  oraz <strong class="text-gray-900">wszystkie powiązane wpisy</strong>.
                  Odniesienia (relacje) do tego modelu w innych wpisach zostaną wyczyszczone.
                </p>

                <p class="text-sm text-gray-600">
                  Wpisz <strong class="font-mono text-gray-900"><%= @delete_target.name %></strong> aby potwierdzić:
                </p>

                <form phx-submit="delete-model" phx-change="update-delete-confirmation" class="space-y-4">
                  <.input
                    type="text"
                    name="confirmation"
                    value={@delete_confirmation}
                    placeholder={@delete_target.name}
                    autocomplete="off"
                  />

                  <div class="flex justify-end gap-3">
                    <button
                      type="button"
                      phx-click="cancel-delete"
                      class="rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
                    >
                      Anuluj
                    </button>
                    <button
                      type="submit"
                      disabled={@delete_confirmation != @delete_target.name}
                      class="rounded-md bg-red-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-red-500 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      Usuń model
                    </button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("confirm-delete", %{"id" => model_id}, socket) do
    prefix = socket.assigns.tenant_prefix
    model = Content.get_model(model_id, prefix)

    {:noreply, assign(socket, delete_target: model, delete_confirmation: "")}
  end

  def handle_event("cancel-delete", _params, socket) do
    {:noreply, assign(socket, delete_target: nil, delete_confirmation: "")}
  end

  def handle_event("update-delete-confirmation", %{"confirmation" => value}, socket) do
    {:noreply, assign(socket, delete_confirmation: value)}
  end

  def handle_event("delete-model", _params, socket) do
    %{delete_target: target, tenant_prefix: prefix} = socket.assigns

    case Content.delete_model(target.id, prefix) do
      {:ok, _model} ->
        models = Content.list_models(prefix)
        collections = Enum.filter(models, &(!&1.is_component))
        components = Enum.filter(models, & &1.is_component)

        {:noreply,
         socket
         |> assign(
           collections: collections,
           components: components,
           delete_target: nil,
           delete_confirmation: ""
         )
         |> put_flash(
           :info,
           "Model \"#{target.name}\" i wszystkie powiązane wpisy zostały usunięte."
         )}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(delete_target: nil, delete_confirmation: "")
         |> put_flash(:error, "Nie udało się usunąć modelu.")}
    end
  end

  defp model_table(assigns) do
    ~H"""
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
                <%= if model.is_component do %>
                  <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{model.slug}/entries"} class="text-indigo-600 hover:text-indigo-900">Edit Data</a>
                <% else %>
                  <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{model.slug}/entries"} class="text-indigo-600 hover:text-indigo-900">Entries</a>
                <% end %>
                <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{model.id}/edit"} class="text-gray-500 hover:text-gray-900">Edit Schema</a>
                <a href={"/admin/tenants/#{@current_tenant.slug}/timeline/model/#{model.id}"} class="text-gray-500 hover:text-gray-900">History</a>
                <button
                  phx-click="confirm-delete"
                  phx-value-id={model.id}
                  class="text-red-500 hover:text-red-700"
                >
                  <.icon name="hero-trash" class="w-4 h-4 inline" />
                </button>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
