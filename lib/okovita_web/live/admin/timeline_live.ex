defmodule OkovitaWeb.Admin.TimelineLive do
  @moduledoc "Tenant admin: view timeline records for an entity."
  use OkovitaWeb, :live_view

  alias Okovita.Timeline

  def mount(%{"entity_type" => entity_type, "entity_id" => entity_id}, _session, socket) do
    prefix = socket.assigns.tenant_prefix
    records = Timeline.list_records(entity_id, entity_type, prefix)

    {:ok,
     assign(socket,
       records: records,
       entity_type: entity_type,
       entity_id: entity_id
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8 px-4 sm:px-6 lg:px-8">
      <div class="pb-5 border-b border-gray-200 mb-8">
        <h1 class="text-3xl font-bold leading-tight text-gray-900">Timeline: <span class="text-indigo-600"><%= @entity_type %></span></h1>
        <p class="mt-2 text-sm text-gray-500">History for Entity ID: <code class="font-mono bg-gray-100 px-1.5 py-0.5 rounded text-gray-800"><%= @entity_id %></code></p>
      </div>

      <%= if @records == [] do %>
        <div class="text-center bg-gray-50 rounded-lg p-12 border-2 border-dashed border-gray-300">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No history</h3>
          <p class="mt-1 text-sm text-gray-500">No timeline records found for this entity.</p>
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
                      <span class="h-8 w-8 rounded-full bg-indigo-50 flex items-center justify-center ring-8 ring-white">
                        <svg class="h-5 w-5 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                        </svg>
                      </span>
                    </div>
                    <div class="min-w-0 flex-1 pt-1.5 flex justify-between space-x-4">
                      <div>
                        <p class="text-sm font-medium text-gray-900 uppercase tracking-wide"><%= record.action %></p>

                        <%= if record.before do %>
                          <details class="mt-3 group cursor-pointer">
                            <summary class="text-sm font-medium text-gray-500 group-hover:text-gray-900 transition-colors">Before State</summary>
                            <pre class="mt-2 bg-gray-50 p-4 rounded-md text-xs font-mono text-gray-800 overflow-x-auto border border-gray-200 shadow-inner"><%= Jason.encode!(record.before, pretty: true) %></pre>
                          </details>
                        <% end %>

                        <%= if record.after do %>
                          <details class="mt-3 group cursor-pointer">
                            <summary class="text-sm font-medium text-gray-500 group-hover:text-gray-900 transition-colors">After State</summary>
                            <pre class="mt-2 bg-gray-50 p-4 rounded-md text-xs font-mono text-gray-800 overflow-x-auto border border-gray-200 shadow-inner"><%= Jason.encode!(record.after, pretty: true) %></pre>
                          </details>
                        <% end %>
                      </div>
                      <div class="text-right text-sm whitespace-nowrap text-gray-500">
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
    </div>
    """
  end
end
