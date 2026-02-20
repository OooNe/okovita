defmodule OkovitaWeb.Admin.TimelineLive do
  @moduledoc "Tenant admin: view timeline records for an entity."
  use OkovitaWeb, :live_view

  alias Okovita.Timeline

  on_mount {OkovitaWeb.LiveAuth, :require_tenant_admin}

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
    <div style="max-width: 800px; margin: 40px auto; padding: 20px;">
      <h1>Timeline: <%= @entity_type %></h1>
      <p style="color: #666; margin-bottom: 20px;">Entity: <code><%= @entity_id %></code></p>

      <%= if @records == [] do %>
        <p style="color: #999;">No timeline records found.</p>
      <% else %>
        <div>
          <%= for record <- @records do %>
            <div style="border-left: 2px solid #4F46E5; padding-left: 16px; margin-bottom: 16px;">
              <div style="display: flex; justify-content: space-between; align-items: center;">
                <strong style="text-transform: uppercase; color: #4F46E5;"><%= record.action %></strong>
                <span style="color: #999; font-size: 12px;"><%= Calendar.strftime(record.inserted_at, "%Y-%m-%d %H:%M:%S") %></span>
              </div>
              <%= if record.before do %>
                <details style="margin-top: 8px;">
                  <summary style="cursor: pointer; color: #666;">Before</summary>
                  <pre style="background: #F3F4F6; padding: 8px; border-radius: 4px; font-size: 12px; overflow-x: auto;"><%= Jason.encode!(record.before, pretty: true) %></pre>
                </details>
              <% end %>
              <%= if record.after do %>
                <details style="margin-top: 4px;">
                  <summary style="cursor: pointer; color: #666;">After</summary>
                  <pre style="background: #F3F4F6; padding: 8px; border-radius: 4px; font-size: 12px; overflow-x: auto;"><%= Jason.encode!(record.after, pretty: true) %></pre>
                </details>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
