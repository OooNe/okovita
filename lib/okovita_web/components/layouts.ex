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
      <link phx-track-static rel="stylesheet" href="/assets/app.css" />
      <script defer phx-track-static type="text/javascript" src="/assets/app.js"></script>
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

  embed_templates "layouts/*"

  defp flash_group(assigns) do
    ~H"""
    <div class="fixed top-4 right-4 z-50 flex flex-col gap-3 w-full max-w-sm pointer-events-none">
      <%= if msg = Phoenix.Flash.get(@flash, :info) do %>
        <div id="flash-info" phx-hook="Flash" phx-mounted={JS.show(transition: {"transition-all transform ease-out duration-500", "translate-x-full opacity-0", "translate-x-0 opacity-100"})} phx-click={JS.push("lv:clear-flash", value: %{key: :info}) |> JS.hide(to: "#flash-info", transition: {"transition-all transform ease-in duration-300", "opacity-100 translate-x-0", "opacity-0 translate-x-full"})} class="hidden pointer-events-auto w-full max-w-sm overflow-hidden rounded-lg bg-white shadow-lg ring-1 ring-black ring-opacity-5 border-l-4 border-green-500 cursor-pointer hover:-translate-y-1 transition-all">
          <div class="p-4">
            <div class="flex items-start">
              <div class="flex-shrink-0">
                <svg class="h-6 w-6 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div class="ml-3 w-0 flex-1 pt-0.5">
                <p class="text-sm font-medium text-gray-900"><%= msg %></p>
              </div>
              <div class="ml-4 flex flex-shrink-0">
                <button type="button" class="inline-flex rounded-md bg-white text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                  <span class="sr-only">Close</span>
                  <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                    <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
                  </svg>
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%= if msg = Phoenix.Flash.get(@flash, :error) do %>
        <div id="flash-error" phx-hook="Flash" phx-mounted={JS.show(transition: {"transition-all transform ease-out duration-500", "translate-x-full opacity-0", "translate-x-0 opacity-100"})} phx-click={JS.push("lv:clear-flash", value: %{key: :error}) |> JS.hide(to: "#flash-error", transition: {"transition-all transform ease-in duration-300", "opacity-100 translate-x-0", "opacity-0 translate-x-full"})} class="hidden pointer-events-auto w-full max-w-sm overflow-hidden rounded-lg bg-white shadow-lg ring-1 ring-black ring-opacity-5 border-l-4 border-red-500 cursor-pointer hover:-translate-y-1 transition-all">
          <div class="p-4">
            <div class="flex items-start">
              <div class="flex-shrink-0">
                <svg class="h-6 w-6 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
              </div>
              <div class="ml-3 w-0 flex-1 pt-0.5">
                <p class="text-sm font-medium text-gray-900"><%= msg %></p>
              </div>
              <div class="ml-4 flex flex-shrink-0">
                <button type="button" class="inline-flex rounded-md bg-white text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                  <span class="sr-only">Close</span>
                  <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                    <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
                  </svg>
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
