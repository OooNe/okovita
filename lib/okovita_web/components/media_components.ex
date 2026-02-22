defmodule OkovitaWeb.MediaComponents do
  @moduledoc """
  Reusable UI components for media management:
  - Upload progress toast
  - Delete confirmation modal
  - Media library picker modal
  """
  use Phoenix.Component

  alias Okovita.Content.MediaUploads

  @doc """
  Renders a floating upload-progress toast panel.

  ## Attributes
  - `upload` - the `@uploads.images` struct from LiveView assigns.
  - `error_to_string` - optional MFA for error label conversion, defaults to built-in strings.
  """
  attr :upload, :map, required: true
  attr :error_fn, :any, default: nil

  def upload_toast(assigns) do
    ~H"""
    <%= if length(@upload.entries) > 0 do %>
      <div class="fixed bottom-6 right-6 w-96 bg-white rounded-xl shadow-2xl border border-gray-200 z-50 overflow-hidden animate-fade-in-up">
        <div class="bg-gray-50 px-4 py-3 border-b border-gray-200 flex justify-between items-center">
          <h3 class="text-sm font-medium text-gray-900">Wgrywanie plików (<%= length(@upload.entries) %>)</h3>
        </div>
        <div class="max-h-64 overflow-y-auto p-4 space-y-3">
          <%= for entry <- @upload.entries do %>
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-md overflow-hidden bg-gray-100 flex-shrink-0">
                <.live_img_preview entry={entry} class="object-cover w-full h-full" />
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex justify-between mb-1">
                  <p class="text-xs font-medium text-gray-900 truncate"><%= entry.client_name %></p>
                  <p class="text-xs text-gray-500"><%= entry.progress %>%</p>
                </div>
                <div class="w-full bg-gray-200 rounded-full h-1.5">
                  <div
                    class="bg-indigo-600 h-1.5 rounded-full transition-all duration-300"
                    style={"width: #{entry.progress}%"}
                  />
                </div>
              </div>
              <button
                type="button"
                phx-click="cancel-upload"
                phx-value-ref={entry.ref}
                class="text-gray-400 hover:text-red-500 p-1"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <%= for err <- upload_errors(@upload, entry) do %>
              <p class="text-[10px] text-red-600 mt-1"><%= upload_error_label(err) %></p>
            <% end %>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders the delete confirmation modal.

  ## Attributes
  - `media_to_delete` – list of media structs pending deletion (nil = hidden).
  - `in_use_warning` – boolean; when true shows "media in use" warning banner.
  """
  attr :media_to_delete, :list, default: nil
  attr :in_use_warning, :boolean, default: false

  def delete_confirmation_modal(assigns) do
    ~H"""
    <%= if @media_to_delete do %>
      <div id="delete-modal" class="relative z-50 pointer-events-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
        <div class="fixed inset-0 bg-gray-900/50 backdrop-blur-sm transition-opacity animate-fade-in"></div>

        <div class="fixed inset-0 z-10 w-screen overflow-y-auto">
          <div class="flex min-h-full items-center justify-center p-4 text-center sm:p-0">
            <div class="relative transform overflow-hidden rounded-xl bg-white shadow-2xl transition-all sm:my-8 sm:w-full sm:max-w-md animate-fade-in-up text-left">
              <div class="p-6">
                <div class="flex items-center justify-center w-12 h-12 mx-auto bg-red-100 rounded-full mb-4">
                  <svg class="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                  </svg>
                </div>

                <h3 class="text-lg font-medium text-gray-900 text-center mb-2">
                  <%= if length(@media_to_delete) == 1, do: "Usuń nośnik", else: "Usuń nośniki (#{length(@media_to_delete)})" %>
                </h3>

                <%= if @in_use_warning do %>
                  <div class="bg-amber-50 rounded-lg p-4 mb-4 border border-amber-200">
                    <div class="flex">
                      <svg class="h-5 w-5 text-amber-400 flex-shrink-0" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                      </svg>
                      <div class="ml-3">
                        <h4 class="text-sm font-medium text-amber-800">
                          Uwaga: <%= if length(@media_to_delete) == 1, do: "Ten plik jest używany", else: "Niektóre z plików są używane" %>
                        </h4>
                        <p class="mt-1 text-sm text-amber-700">
                          Wygląda na to, że <%= if length(@media_to_delete) == 1, do: "to zdjęcie jest obecnie powiązane", else: "część z wybranych zdjęć jest powiązana" %> z co najmniej jednym wpisem. Gwałtowne usunięcie może spowodować puste pola w opublikowanych treściach.
                        </p>
                      </div>
                    </div>
                  </div>
                <% else %>
                  <p class="text-sm text-gray-500 text-center mb-6">
                    Czy na pewno chcesz bezpowrotnie usunąć
                    <%= if length(@media_to_delete) == 1 do %>
                      ten plik (<span class="font-semibold text-gray-700 truncate inline-block align-bottom max-w-[150px]"><%= hd(@media_to_delete).file_name %></span>)?
                    <% else %>
                      te pliki (<span class="font-semibold text-gray-700"><%= length(@media_to_delete) %></span> wybranych)?
                    <% end %>
                    Tej operacji nie można cofnąć.
                  </p>
                <% end %>

                <div class="mt-6 flex gap-3 justify-center">
                  <button type="button" phx-click="cancel-delete" class="px-4 py-2 bg-white text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-gray-200 font-medium transition-colors w-full">
                    Anuluj
                  </button>
                  <button type="button" phx-click="confirm-delete" class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 font-medium transition-colors w-full flex justify-center items-center">
                    <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                    Usuń
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders a full-screen modal picker for selecting media from the library.

  ## Attributes
  - `picker_open` – nil (hidden) or %{field: field_name, mode: :single | :multi}
  - `picker_selection` – MapSet of selected media IDs
  - `media_items` – list of media structs for the current tenant
  """
  attr :picker_open, :map, default: nil
  attr :picker_selection, :any, required: true
  attr :media_items, :list, required: true

  def media_picker_modal(assigns) do
    ~H"""
    <%= if @picker_open do %>
      <%!-- Backdrop --%>
      <div class="fixed inset-0 bg-gray-900/60 backdrop-blur-sm z-40"
           phx-click="picker-cancel" />

      <%!-- Panel --%>
      <div class="fixed inset-x-4 inset-y-6 sm:inset-x-auto sm:left-1/2 sm:-translate-x-1/2
                  sm:w-full sm:max-w-4xl bg-white rounded-2xl shadow-2xl z-50
                  flex flex-col overflow-hidden animate-fade-in-up">

        <%!-- Header --%>
        <div class="flex items-center justify-between px-6 py-4 border-b border-gray-200 flex-shrink-0">
          <div>
            <h2 class="text-lg font-semibold text-gray-900">Biblioteka mediów</h2>
            <p class="text-xs text-gray-500 mt-0.5">
              <%= if @picker_open.mode == :single do %>
                Wybierz jeden plik
              <% else %>
                Wybierz jeden lub więcej plików
              <% end %>
            </p>
          </div>
          <button type="button" phx-click="picker-cancel"
                  class="text-gray-400 hover:text-gray-600 transition-colors p-1 rounded-lg hover:bg-gray-100">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <%!-- Scrollable media grid --%>
        <div class="flex-1 overflow-y-auto p-6">
          <%= if Enum.empty?(@media_items) do %>
            <div class="flex flex-col items-center justify-center h-48 text-gray-400">
              <svg class="w-12 h-12 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1"
                      d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              <p class="text-sm">Brak plików w bibliotece</p>
            </div>
          <% else %>
            <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 lg:grid-cols-6 gap-3">
              <%= for item <- @media_items do %>
                <% selected? = MapSet.member?(@picker_selection, item.id) %>
                <button type="button"
                        phx-click="picker-toggle-select"
                        phx-value-id={item.id}
                        class={["group relative rounded-xl overflow-hidden border-2 transition-all
                                 aspect-square focus:outline-none focus:ring-2 focus:ring-indigo-500",
                                 if(selected?,
                                   do: "border-indigo-600 ring-2 ring-indigo-500/30",
                                   else: "border-gray-200 hover:border-indigo-400")]}>
                  <%= if String.starts_with?(item.mime_type, "image/") do %>
                    <img src={item.url} alt={item.file_name} loading="lazy"
                         class="object-cover w-full h-full transition-opacity group-hover:opacity-90" />
                  <% else %>
                    <div class="flex items-center justify-center w-full h-full bg-gray-50 text-gray-400">
                      <svg class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"
                              d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                      </svg>
                    </div>
                  <% end %>
                  <%!-- Selection overlay badge --%>
                  <div class={["absolute inset-0 transition-colors",
                               if(selected?, do: "bg-indigo-600/10", else: "")]} />
                  <div class={["absolute top-1.5 right-1.5 w-5 h-5 rounded-full border-2
                                flex items-center justify-center transition-all shadow-sm",
                                if(selected?,
                                  do: "bg-indigo-600 border-indigo-600",
                                  else: "bg-white/80 border-gray-300 opacity-0 group-hover:opacity-100")]}>
                    <%= if selected? do %>
                      <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                      </svg>
                    <% end %>
                  </div>
                  <%!-- Filename tooltip on hover --%>
                  <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/60 to-transparent
                              p-1.5 translate-y-full group-hover:translate-y-0 transition-transform">
                    <p class="text-[10px] text-white truncate" title={item.file_name}><%= item.file_name %></p>
                  </div>
                </button>
              <% end %>
            </div>
          <% end %>
        </div>

        <%!-- Footer --%>
        <div class="flex items-center justify-between px-6 py-4 border-t border-gray-200 flex-shrink-0 bg-gray-50/50">
          <span class="text-sm text-gray-500">
            <%= case MapSet.size(@picker_selection) do %>
              <% 0 -> %>Nie wybrano żadnego pliku
              <% n -> %>Wybrano: <span class="font-semibold text-gray-800"><%= n %></span>
                       <%= if @picker_open.mode == :single, do: "(maks. 1)", else: "" %>
            <% end %>
          </span>
          <div class="flex gap-3">
            <button type="button" phx-click="picker-cancel"
                    class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300
                           rounded-lg hover:bg-gray-50 transition-colors">
              Anuluj
            </button>
            <button type="button" phx-click="picker-confirm"
                    phx-value-field={@picker_open.field}
                    phx-value-mode={@picker_open.mode}
                    disabled={MapSet.size(@picker_selection) == 0}
                    class="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg
                           hover:bg-indigo-700 disabled:opacity-40 disabled:cursor-not-allowed
                           transition-colors flex items-center gap-2">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              Dodaj
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp upload_error_label(err), do: MediaUploads.upload_error_label(err)
end
