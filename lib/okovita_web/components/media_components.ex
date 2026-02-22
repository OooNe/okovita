defmodule OkovitaWeb.MediaComponents do
  @moduledoc """
  Reusable UI components for media management:
  - Upload progress toast
  - Delete confirmation modal
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

  defp upload_error_label(err), do: MediaUploads.upload_error_label(err)
end
