defmodule OkovitaWeb.Admin.MediaLive.Index do
  use OkovitaWeb, :live_view

  alias Okovita.Content

  @impl true
  def mount(_params, _session, socket) do
    prefix = socket.assigns.tenant_prefix

    media_items = Content.list_media(prefix)

    socket =
      socket
      |> assign(:active_nav, "media")
      |> assign(:media_items, media_items)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col space-y-6">
      <div class="flex justify-between items-center pb-4 border-b border-gray-200">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900">Biblioteka Mediów</h1>
          <p class="text-sm text-gray-500 mt-1">Przeglądaj wszystkie pliki wgrane w obrębie tego projektu.</p>
        </div>
      </div>

      <%= if Enum.empty?(@media_items) do %>
        <div class="text-center py-24 bg-white rounded-lg border border-gray-200 shadow-sm">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">Brak mediów</h3>
          <p class="mt-1 text-sm text-gray-500">
            Kiedy dodasz pierwsze zdjęcie w artykułach lub modelach, pojawi się ono tutaj.
          </p>
        </div>
      <% else %>
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-6">
          <%= for item <- @media_items do %>
            <div class="group relative flex flex-col bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden hover:shadow-md transition-shadow">
              <div class="aspect-w-1 aspect-h-1 w-full overflow-hidden bg-gray-100">
                <%= if String.starts_with?(item.mime_type, "image/") do %>
                  <img src={item.url} alt={item.file_name} class="h-full w-full object-cover object-center group-hover:opacity-75 transition-opacity" loading="lazy" />
                <% else %>
                  <div class="flex items-center justify-center h-full w-full bg-gray-50 text-gray-400">
                    <svg class="h-10 w-10" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                  </div>
                <% end %>
              </div>
              <div class="p-3 flex flex-col flex-1">
                <p class="text-xs font-medium text-gray-900 truncate" title={item.file_name}>
                  <%= item.file_name %>
                </p>
                <div class="mt-1 flex justify-between items-center text-[10px] text-gray-500">
                  <span class="truncate pr-2"><%= item.mime_type %></span>
                  <span><%= format_size(item.size) %></span>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_size(nil), do: "0 B"
  defp format_size(size) when size < 1024, do: "#{size} B"
  defp format_size(size) when size < 1024 * 1024, do: "#{Float.round(size / 1024, 1)} KB"
  defp format_size(size), do: "#{Float.round(size / (1024 * 1024), 2)} MB"
end
