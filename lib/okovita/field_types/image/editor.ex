defmodule Okovita.FieldTypes.Image.Editor do
  @moduledoc """
  Editor component for the `image` field type.

  Renders an upload zone with two options:
  - Direct file upload (via LiveView uploads)
  - Pick from media library (via media-picker modal)
  """
  use Phoenix.Component

  attr :name, :string, required: true
  # %{id: str, url: str} or nil
  attr :media_value, :map, default: nil
  # entry from @uploads[field_atom]
  attr :upload, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="mt-2" phx-drop-target={@upload.ref}>
      <%!-- Preview of currently selected/uploaded image --%>
      <%= if @media_value && (@media_value[:url] || @media_value["url"]) do %>
        <% url = @media_value[:url] || @media_value["url"] %>
        <div class="mb-4 relative w-32 h-32 rounded-lg border border-gray-200 overflow-hidden bg-gray-50 flex items-center justify-center">
          <img src={url} alt="Uploaded Image" class="object-cover w-full h-full" />
        </div>
      <% end %>

      <%!-- Upload zone with two halves: file upload | media library --%>
      <div class="flex rounded-xl border border-gray-200 overflow-hidden shadow-sm" phx-drop-target={@upload.ref}>
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
          <span class="text-sm font-medium text-gray-700 group-hover:text-indigo-700 transition-colors">Wgraj plik</span>
          <span class="text-xs text-gray-400">PNG, JPG, WEBP</span>
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
          phx-value-mode="single"
          onclick="event.preventDefault()"
          class="flex-1 flex flex-col items-center justify-center gap-2 py-7 px-4
                 bg-white hover:bg-violet-50/40 cursor-pointer transition-colors group border-none"
        >
          <div class="w-10 h-10 rounded-full bg-violet-50 flex items-center justify-center
                      group-hover:bg-violet-100 transition-colors">
            <svg class="w-5 h-5 text-violet-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828
                       0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
          </div>
          <span class="text-sm font-medium text-gray-700 group-hover:text-violet-700 transition-colors">Z biblioteki mediów</span>
          <span class="text-xs text-gray-400">Wybierz istniejący plik</span>
        </button>
      </div>

      <%!-- Upload entry previews with progress --%>
      <%= for entry <- @upload.entries do %>
        <div class="flex items-center space-x-4 p-4 mt-4 bg-white rounded-lg border border-gray-200 shadow-sm">
          <div class="relative w-16 h-16 rounded overflow-hidden">
            <.live_img_preview entry={entry} class="object-cover w-full h-full" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-gray-900 truncate"><%= entry.client_name %></p>
            <div class="w-full bg-gray-200 rounded-full h-2.5 mt-2">
              <div class="bg-indigo-600 h-2.5 rounded-full" style={"width: #{entry.progress}%"}></div>
            </div>
          </div>
          <button
            type="button"
            phx-click="cancel-upload"
            phx-value-ref={entry.ref}
            phx-value-name={@name}
            class="text-gray-400 hover:text-red-500 transition-colors"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <%= for err <- upload_errors(@upload, entry) do %>
          <p class="mt-1 text-sm text-red-600"><%= upload_error_label(err) %></p>
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
