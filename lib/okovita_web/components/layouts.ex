defmodule OkovitaWeb.Layouts do
  @moduledoc """
  Layout components for the admin dashboard.
  """
  use OkovitaWeb, :html

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <meta name="csrf-token" content={get_csrf_token()} />
      <title>Okovita CMS</title>
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; color: #111827; background: #F9FAFB; }
        a { color: #4F46E5; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .flash-info { background: #D1FAE5; color: #065F46; padding: 12px; border-radius: 4px; margin: 20px auto; max-width: 900px; }
        .flash-error { background: #FEE2E2; color: #991B1B; padding: 12px; border-radius: 4px; margin: 20px auto; max-width: 900px; }
      </style>
      <script defer phx-track-static src="/assets/app.js"></script>
    </head>
    <body>
      <%= @inner_content %>
    </body>
    </html>
    """
  end

  def app(assigns) do
    ~H"""
    <main>
      <.flash_group flash={@flash} />
      <%= @inner_content %>
    </main>
    """
  end

  defp flash_group(assigns) do
    ~H"""
    <%= if Phoenix.Flash.get(@flash, :info) do %>
      <div class="flash-info"><%= Phoenix.Flash.get(@flash, :info) %></div>
    <% end %>
    <%= if Phoenix.Flash.get(@flash, :error) do %>
      <div class="flash-error"><%= Phoenix.Flash.get(@flash, :error) %></div>
    <% end %>
    """
  end
end
