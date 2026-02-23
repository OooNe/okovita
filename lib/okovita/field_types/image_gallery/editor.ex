defmodule Okovita.FieldTypes.ImageGallery.Editor do
  @moduledoc """
  Editor component for the `image_gallery` field type.

  Renders a sortable grid of existing images plus an upload zone with two options:
  - Direct file upload (via LiveView uploads)
  - Pick from media library (multi-select via media-picker modal)
  """
  use Phoenix.Component

  attr :name, :string, required: true
  # list of %{"media_id" => id, "index" => i, "url" => url?}
  attr :value, :list, default: []
  # entry from @uploads[field_atom]
  attr :upload, :map, required: true

  def render(assigns) do
    sorted_value = Enum.sort_by(assigns.value || [], & &1["index"])
    assigns = assign(assigns, :sorted_value, sorted_value)

    ~H"""
    <div class="mt-2 flex flex-col space-y-4" phx-drop-target={@upload.ref}>
      <%!-- Existing images sortable grid --%>
      <%= if length(@sorted_value) > 0 do %>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4" phx-hook="Sortable" id={"sortable-#{@name}"}>
          <%= for item <- @sorted_value do %>
            <div class="relative group w-full h-32 rounded-lg border border-gray-200 overflow-hidden bg-gray-50 flex items-center justify-center cursor-move">
              <%= if item["url"] || item[:url] do %>
                <img src={item["url"] || item[:url]} alt="Gallery Image" class="object-cover w-full h-full pointer-events-none" />
              <% end %>
              <%!-- Hidden input to preserve media_id ordering for SortableJS and form submission --%>
              <input type="hidden" name={"#{@name}__existing[]"} value={item["media_id"]} />
              <button
                type="button"
                phx-click="remove-gallery-image"
                phx-value-name={@name}
                phx-value-index={item["index"]}
                class="absolute top-2 right-2 bg-white bg-opacity-75 rounded-full p-1 text-gray-700
                       hover:text-red-500 hover:bg-opacity-100 transition-all opacity-0 group-hover:opacity-100"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          <% end %>
        </div>
      <% end %>

      <%!-- Upload zone with two halves: file upload | media library --%>
      <div class="flex rounded-xl border border-gray-200 overflow-hidden shadow-sm">
        <%!-- Left: file upload --%>
        <label
          for={@upload.ref}
          class="flex-1 flex flex-col items-center justify-center gap-2 py-7 px-4
                 bg-white hover:bg-indigo-50/40 cursor-pointer transition-colors group"
        >
          <div class="w-10 h-10 rounded-full bg-indigo-50 flex items-center justify-center
                      group-hover:bg-indigo-100 transition-colors">
            <svg class="w-5 h-5 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
            </svg>
          </div>
          <span class="text-sm font-medium text-gray-700 group-hover:text-indigo-700 transition-colors">Wgraj pliki</span>
          <span class="text-xs text-gray-400">PNG, JPG, WEBP · maks. 20</span>
          <.live_file_input upload={@upload} class="hidden" />
        </label>

        <%!-- Divider --%>
        <div class="flex flex-col items-center justify-center gap-1 py-4">
          <div class="w-px flex-1 bg-gray-100"></div>
          <span class="text-[10px] font-medium text-gray-300 tracking-widest uppercase px-1">lub</span>
          <div class="w-px flex-1 bg-gray-100"></div>
        </div>

        <%!-- Right: media library --%>
        <button
          type="button"
          phx-click="open-media-picker"
          phx-value-field={@name}
          phx-value-mode="multi"
          onclick="event.preventDefault()"
          class="flex-1 flex flex-col items-center justify-center gap-2 py-7 px-4
                 bg-white hover:bg-violet-50/40 cursor-pointer transition-colors group border-none"
        >
          <div class="w-10 h-10 rounded-full bg-violet-50 flex items-center justify-center
                      group-hover:bg-violet-100 transition-colors">
            <svg class="w-5 h-5 text-violet-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14
                       m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
          </div>
          <span class="text-sm font-medium text-gray-700 group-hover:text-violet-700 transition-colors">Z biblioteki mediów</span>
          <span class="text-xs text-gray-400">Wybierz istniejące pliki</span>
        </button>
      </div>

      <%!-- In-progress upload previews grid --%>
      <%= if length(@upload.entries) > 0 do %>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-4">
          <%= for entry <- @upload.entries do %>
            <div class="relative w-full h-32 rounded-lg border border-gray-200 overflow-hidden shadow-sm">
              <.live_img_preview entry={entry} class="object-cover w-full h-full" />
              <div class="absolute bottom-0 left-0 right-0 bg-white bg-opacity-90 p-2">
                <div class="w-full bg-gray-200 rounded-full h-1.5">
                  <div class="bg-indigo-600 h-1.5 rounded-full" style={"width: #{entry.progress}%"}></div>
                </div>
              </div>
              <button
                type="button"
                phx-click="cancel-upload"
                phx-value-ref={entry.ref}
                phx-value-name={@name}
                class="absolute top-2 right-2 bg-white bg-opacity-75 rounded-full p-1 text-gray-700 hover:text-red-500 transition-colors"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          <% end %>
        </div>
      <% end %>

      <%!-- Upload errors --%>
      <%= for entry <- @upload.entries do %>
        <%= for err <- upload_errors(@upload, entry) do %>
          <p class="mt-1 text-sm text-red-600 truncate"><%= entry.client_name %>: <%= upload_error_label(err) %></p>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp upload_error_label(:too_large), do: "File is too large"
  defp upload_error_label(:too_many_files), do: "You have selected too many files"
  defp upload_error_label(:not_accepted), do: "You have selected an unacceptable file type"
  defp upload_error_label(_), do: "Upload error"
end
