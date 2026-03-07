defmodule Okovita.FieldTypes.Image.Editor do
  @moduledoc """
  Editor component for the `image` field type.

  Renders an upload zone with two options:
  - Direct file upload (via LiveView uploads)
  - Pick from media library (via media-picker modal)
  """
  use Phoenix.Component
  import OkovitaWeb.FormatHelpers

  attr :name, :string, required: true
  # %{id: str, url: str} or nil
  attr :media_value, :map, default: nil
  # entry from @uploads[field_atom]
  attr :upload, :map, required: true
  attr :active_field_modal, :string, default: nil

  def render(assigns) do
    ~H"""
    <div>
      <%!-- Trigger Button and Mini Preview --%>
      <div class="mt-2 flex flex-col items-start gap-3">
        <%= if @media_value && (@media_value[:url] || @media_value["url"]) do %>
          <% url = @media_value[:url] || @media_value["url"] %>
          <div class="relative w-16 h-16 rounded-lg border border-gray-200 overflow-hidden bg-gray-50 flex items-center justify-center shadow-sm">
            <img src={proxy_url(url, w: 100, h: 100, fit: "cover")} alt="Uploaded Image" class="object-cover w-full h-full" />
          </div>
        <% end %>
        <button type="button" phx-click="open-field-modal" phx-value-field={@name}
                class="w-fit px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 flex items-center gap-2 transition-colors shadow-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
          <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
          <%= if @media_value && (@media_value[:url] || @media_value["url"]), do: "Zmień zdjęcie", else: "Dodaj zdjęcie" %>
        </button>
      </div>

      <%!-- Modal Layer (Hidden unless active) --%>
      <div class={if @active_field_modal == @name, do: "fixed inset-0 z-50", else: "hidden"}>
        <div class="fixed inset-0 bg-gray-900/60 backdrop-blur-sm transition-opacity" phx-click="close-field-modal" aria-hidden="true"></div>

        <div class="fixed inset-x-4 inset-y-6 sm:inset-x-auto sm:left-1/2 sm:-translate-x-1/2 sm:w-full sm:max-w-4xl bg-white rounded-2xl shadow-2xl z-50 flex flex-col overflow-hidden animate-fade-in-up">
          <div class="flex items-center justify-between px-6 py-4 border-b border-gray-200 bg-white flex-shrink-0 z-10">
            <h3 class="text-lg font-semibold text-gray-900">Zarządzaj zdjęciem</h3>
            <button type="button" phx-click="close-field-modal" class="text-gray-400 hover:text-gray-600 transition-colors p-1 rounded-lg hover:bg-gray-100 focus:outline-none">
              <span class="sr-only">Zamknij</span>
              <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <div class="p-6 overflow-y-auto flex-1 bg-gray-50/30" phx-drop-target={@upload.ref}>
            <%!-- Preview of currently selected/uploaded image --%>
            <%= if @media_value && (@media_value[:url] || @media_value["url"]) do %>
              <% url = @media_value[:url] || @media_value["url"] %>
              <div class="mb-6 relative w-48 h-48 rounded-xl border-2 border-gray-200 overflow-hidden bg-white flex items-center justify-center mx-auto shadow-sm">
                <img src={proxy_url(url, w: 400, h: 400, fit: "cover")} alt="Uploaded Image" class="object-cover w-full h-full" />
              </div>
            <% end %>

            <%!-- Upload zone with two halves: file upload | media library --%>
            <div class="flex rounded-xl border border-gray-200 overflow-hidden shadow-sm bg-white" phx-drop-target={@upload.ref}>
              <%!-- Left: file upload --%>
              <label
                for={@upload.ref}
                class="flex-1 flex flex-col items-center justify-center gap-2 py-8 px-4
                       hover:bg-indigo-50/50 cursor-pointer transition-colors group"
              >
                <div class="w-12 h-12 rounded-full bg-indigo-50 flex items-center justify-center
                            group-hover:bg-indigo-100 transition-colors text-indigo-500 group-hover:text-indigo-600">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                          d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                  </svg>
                </div>
                <span class="text-sm font-medium text-gray-700 group-hover:text-indigo-700 transition-colors">Wgraj plik z dysku</span>
                <span class="text-xs text-gray-400">PNG, JPG, WEBP, GIF</span>
                <.live_file_input upload={@upload} class="hidden" />
              </label>

              <%!-- Divider --%>
              <div class="flex flex-col items-center justify-center gap-2 py-4 px-2">
                <div class="w-px flex-1 bg-gray-100"></div>
                <span class="text-[10px] font-bold text-gray-300 tracking-wider uppercase">lub</span>
                <div class="w-px flex-1 bg-gray-100"></div>
              </div>

              <%!-- Right: media library --%>
              <button
                type="button"
                phx-click="open-media-picker"
                phx-value-field={@name}
                phx-value-mode="single"
                onclick="event.preventDefault()"
                class="flex-1 flex flex-col items-center justify-center gap-2 py-8 px-4
                       hover:bg-violet-50/50 cursor-pointer transition-colors group border-none"
              >
                <div class="w-12 h-12 rounded-full bg-violet-50 flex items-center justify-center
                            group-hover:bg-violet-100 transition-colors text-violet-500 group-hover:text-violet-600">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                          d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828
                             0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                </div>
                <span class="text-sm font-medium text-gray-700 group-hover:text-violet-700 transition-colors">Wybierz z biblioteki</span>
                <span class="text-xs text-gray-400">Wybierz zapisany plik</span>
              </button>
            </div>

            <%!-- Upload entry previews with progress --%>
            <%= for entry <- @upload.entries do %>
              <div class="flex items-center space-x-4 p-4 mt-6 bg-white rounded-xl border border-gray-200 shadow-sm animate-fade-in">
                <div class="relative w-16 h-16 rounded-lg border border-gray-100 overflow-hidden bg-gray-50 flex-shrink-0">
                  <.live_img_preview entry={entry} class="object-cover w-full h-full" />
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium text-gray-900 truncate mb-1"><%= entry.client_name %></p>
                  <div class="w-full bg-gray-200 rounded-full h-2">
                    <div class="bg-indigo-600 h-2 rounded-full transition-all duration-300" style={"width: #{entry.progress}%"}></div>
                  </div>
                  <p class="text-xs text-gray-500 mt-1"><%= entry.progress %>%</p>
                </div>
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  phx-value-name={@name}
                  class="text-gray-400 hover:text-red-500 transition-colors p-2 hover:bg-red-50 rounded-full focus:outline-none"
                  title="Anuluj"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <%= for err <- upload_errors(@upload, entry) do %>
                <p class="mt-2 text-sm text-red-600 font-medium bg-red-50 p-3 rounded-lg border border-red-100">
                  <svg class="w-4 h-4 inline mr-1 -mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                  <%= upload_error_label(err) %>
                </p>
              <% end %>
            <% end %>
          </div>

          <div class="flex items-center justify-end px-6 py-4 border-t border-gray-200 flex-shrink-0 bg-gray-50/50">
            <button type="button" phx-click="close-field-modal" class="px-6 py-2 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 transition-colors shadow-sm">
              Zastosuj i zamknij
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp upload_error_label(:too_large), do: "File is too large"
  defp upload_error_label(:too_many_files), do: "You have selected too many files"
  defp upload_error_label(:not_accepted), do: "You have selected an unacceptable file type"
  defp upload_error_label(_), do: "Upload error"
end
