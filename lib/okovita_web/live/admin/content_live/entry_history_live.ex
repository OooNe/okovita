defmodule OkovitaWeb.Admin.ContentLive.EntryHistoryLive do
  @moduledoc "Tenant admin: view history for a specific content entry."
  use OkovitaWeb, :live_view

  alias Okovita.Content.{Models, Entries}
  alias Okovita.Timeline

  def mount(
        %{"model_slug" => model_slug, "id" => id, "tenant_slug" => tenant_slug},
        _session,
        socket
      ) do
    prefix = socket.assigns.tenant_prefix

    case {Models.get_model_by_slug(model_slug, prefix), Entries.get_entry(id, prefix)} do
      {nil, _} ->
        {:ok,
         put_flash(socket, :error, "Model not found")
         |> push_navigate(to: "/admin/tenants/#{tenant_slug}/models")}

      {_, nil} ->
        {:ok,
         put_flash(socket, :error, "Entry not found")
         |> push_navigate(to: "/admin/tenants/#{tenant_slug}/models/#{model_slug}/entries")}

      {model, entry} ->
        records = Timeline.list_records(entry.id, "entry", prefix)

        {:ok,
         assign(socket,
           model: model,
           entry: entry,
           records: records,
           tenant_slug: tenant_slug
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto bg-white rounded-xl shadow-sm ring-1 ring-gray-900/5 p-8">
      <h1 class="text-2xl font-bold text-gray-900 mb-6">
        Historia wpisu — <span class="text-indigo-600"><%= @model.name %></span>
      </h1>

      <div class="border-b border-gray-200 mb-8">
        <nav class="-mb-px flex space-x-8" aria-label="Tabs">
          <a href={"/admin/tenants/#{@tenant_slug}/models/#{@model.slug}/entries/#{@entry.id}/edit"}
             class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 transition-colors">
            Edycja
          </a>

          <a href={"/admin/tenants/#{@tenant_slug}/models/#{@model.slug}/entries/#{@entry.id}/history"}
             class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm border-indigo-500 text-indigo-600"
             aria-current="page">
            Historia
          </a>
        </nav>
      </div>

      <%= if @records == [] do %>
        <div class="text-center py-12 px-4 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">Brak historii</h3>
          <p class="mt-1 text-sm text-gray-500">Nie znaleziono żadnych zapisów historycznych dla tego wpisu.</p>
        </div>
      <% else %>
        <div class="flow-root">
          <ul role="list" class="-mb-8">
            <%= for {record, index} <- Enum.with_index(@records) do %>
              <li>
                <div class="relative pb-8">
                  <%= if index < length(@records) - 1 do %>
                    <span class="absolute top-4 left-4 -ml-px h-full w-0.5 bg-gray-200" aria-hidden="true"></span>
                  <% end %>
                  <div class="relative flex space-x-3">
                    <div>
                      <span class="h-8 w-8 rounded-full bg-indigo-50 flex items-center justify-center ring-8 ring-white shadow-sm">
                        <svg class="h-4 w-4 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                        </svg>
                      </span>
                    </div>
                    <div class="min-w-0 flex-1 pt-1.5 flex justify-between space-x-4">
                      <div>
                        <p class="text-sm font-semibold text-gray-900 uppercase tracking-wider"><%= record.action %></p>

                        <div class="mt-4 space-y-4">
                          <%= if record.before do %>
                            <details class="group">
                              <summary class="text-xs font-medium text-gray-500 hover:text-gray-900 transition-colors cursor-pointer list-none flex items-center gap-1">
                                <svg class="w-3 h-3 transition-transform group-open:rotate-90" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" /></svg>
                                Stan PRZED
                              </summary>
                              <div class="mt-2 text-xs font-mono bg-gray-50 p-4 rounded-lg border border-gray-200 overflow-x-auto shadow-inner text-gray-800">
                                <pre><%= Jason.encode!(record.before, pretty: true) %></pre>
                              </div>
                            </details>
                          <% end %>

                          <%= if record.after do %>
                            <details class="group" open>
                              <summary class="text-xs font-medium text-gray-500 hover:text-gray-900 transition-colors cursor-pointer list-none flex items-center gap-1">
                                <svg class="w-3 h-3 transition-transform group-open:rotate-90" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" /></svg>
                                Stan PO
                              </summary>
                              <div class="mt-2 text-xs font-mono bg-indigo-50/30 p-4 rounded-lg border border-indigo-100/50 overflow-x-auto shadow-inner text-gray-800">
                                <pre><%= Jason.encode!(record.after, pretty: true) %></pre>
                              </div>
                            </details>
                          <% end %>
                        </div>
                      </div>
                      <div class="text-right text-xs whitespace-nowrap text-gray-500 font-medium">
                        <time datetime={record.inserted_at}><%= Calendar.strftime(record.inserted_at, "%Y-%m-%d %H:%M:%S") %></time>
                      </div>
                    </div>
                  </div>
                </div>
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <div class="mt-12 pt-6 border-t border-gray-200">
        <a href={"/admin/tenants/#{@tenant_slug}/models/#{@model.slug}/entries"}
           class="text-sm font-medium text-gray-600 hover:text-gray-900 transition-colors flex items-center gap-2">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" /></svg>
          Powrót do listy
        </a>
      </div>
    </div>
    """
  end
end
