defmodule OkovitaWeb.Admin.MediaLive.Index do
  use OkovitaWeb, :live_view

  import OkovitaWeb.MediaComponents
  import OkovitaWeb.FormatHelpers

  alias Okovita.Content
  alias Okovita.Content.MediaUploads

  @impl true
  def mount(_params, _session, socket) do
    prefix = socket.assigns.tenant_prefix

    media_items = Content.list_media(prefix)

    socket =
      socket
      |> assign(:active_nav, "media")
      |> assign(:media_items, media_items)
      |> assign(:media_to_delete, nil)
      |> assign(:media_in_use_warning, false)
      |> assign(:selected_media, MapSet.new())
      |> allow_upload(:images,
        accept: ~w(.jpg .jpeg .png .gif .webp),
        max_entries: 20,
        auto_upload: true,
        progress: &handle_progress/3
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle-select", %{"id" => id}, socket) do
    selected = socket.assigns.selected_media

    updated_selected =
      if MapSet.member?(selected, id) do
        MapSet.delete(selected, id)
      else
        MapSet.put(selected, id)
      end

    {:noreply, assign(socket, :selected_media, updated_selected)}
  end

  @impl true
  def handle_event("clear-selection", _params, socket) do
    {:noreply, assign(socket, :selected_media, MapSet.new())}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :images, ref)}
  end

  @impl true
  def handle_event("request-delete", %{"id" => id}, socket) do
    prefix = socket.assigns.tenant_prefix
    media = Enum.find(socket.assigns.media_items, &(&1.id == id))

    if media do
      in_use? = Content.media_in_use?(id, prefix)

      socket =
        socket
        |> assign(:media_to_delete, [media])
        |> assign(:media_in_use_warning, in_use?)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("request-delete-batch", _params, socket) do
    prefix = socket.assigns.tenant_prefix
    selected_ids = MapSet.to_list(socket.assigns.selected_media)

    media_list = Enum.filter(socket.assigns.media_items, &(&1.id in selected_ids))

    if length(media_list) > 0 do
      in_use? = Content.any_media_in_use?(selected_ids, prefix)

      socket =
        socket
        |> assign(:media_to_delete, media_list)
        |> assign(:media_in_use_warning, in_use?)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel-delete", _params, socket) do
    socket =
      socket
      |> assign(:media_to_delete, nil)
      |> assign(:media_in_use_warning, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm-delete", _params, socket) do
    if media_list = socket.assigns.media_to_delete do
      prefix = socket.assigns.tenant_prefix
      ids_to_delete = Enum.map(media_list, & &1.id)

      case Content.delete_all_media(ids_to_delete, prefix) do
        {deleted_count, _} when deleted_count > 0 ->
          media_items = Content.list_media(prefix)

          socket =
            socket
            |> assign(:media_to_delete, nil)
            |> assign(:media_in_use_warning, false)
            |> assign(:selected_media, MapSet.new())
            |> assign(:media_items, media_items)
            |> put_flash(:info, "Pomyślnie usunięto zasoby (#{deleted_count}) z systemu.")

          {:noreply, socket}

        _ ->
          socket =
            socket
            |> put_flash(:error, "Nie udało się usunąć wybranych plików.")

          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save", _params, socket) do
    # Fallback if form is submitted manually
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form id="media-library-form" phx-change="validate" phx-submit="save"
          phx-drop-target={@uploads.images.ref}
          class="group flex flex-col space-y-6 min-h-[calc(100vh-8rem)] relative rounded-xl transition-colors">
      <.live_file_input upload={@uploads.images} class="hidden" />

      <.dropzone_overlay />
      <.library_header selected_media={@selected_media} uploads={@uploads} />
      <.upload_toast upload={@uploads.images} />
      <.media_grid media_items={@media_items} selected_media={@selected_media} />
      <.delete_confirmation_modal media_to_delete={@media_to_delete} in_use_warning={@media_in_use_warning} />
    </form>
    """
  end

  # ── Private View Components ────────────────────────────────────────

  defp dropzone_overlay(assigns) do
    ~H"""
    <div id="dropzone-overlay"
         class="hidden pointer-events-none absolute inset-0 z-50 bg-gray-50/90 backdrop-blur-md
                border-4 border-dashed border-indigo-500 rounded-xl items-center justify-center
                transition-all group-[.phx-drop-target-active]:flex">
      <div class="bg-white px-10 py-8 rounded-2xl shadow-xl flex flex-col items-center animate-fade-in-up">
        <div class="w-20 h-20 bg-indigo-50 text-indigo-600 rounded-full flex items-center justify-center mb-5 shadow-inner">
          <svg class="w-10 h-10" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
          </svg>
        </div>
        <p class="text-2xl font-bold text-gray-900 mb-2">Upuść pliki tutaj</p>
        <p class="text-base text-gray-500">Aby błyskawicznie wgrać je na serwer</p>
      </div>
    </div>
    """
  end

  attr :selected_media, :any, required: true
  attr :uploads, :any, required: true

  defp library_header(assigns) do
    ~H"""
    <div class="flex flex-col md:flex-row md:items-center justify-between pb-4 border-b border-gray-200 gap-4">
      <div>
        <h1 class="text-2xl font-semibold text-gray-900">Biblioteka Mediów</h1>
        <p class="text-sm text-gray-500 mt-1">Przeglądaj wszystkie pliki wgrane w obrębie tego projektu.</p>
      </div>
      <div class="flex items-center gap-4 flex-wrap justify-end">
        <%= if MapSet.size(@selected_media) > 0 do %>
          <div class="flex items-center gap-3 bg-white px-3 py-1.5 rounded-md border border-gray-200 animate-fade-in shadow-sm">
            <span class="text-xs font-medium text-gray-700">
              Wybrano: <span class="font-semibold text-gray-900"><%= MapSet.size(@selected_media) %></span>
            </span>
            <div class="w-px h-4 bg-gray-200 mx-1"></div>
            <button type="button" phx-click="clear-selection"
                    class="px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-100 rounded-md transition-colors">
              Anuluj
            </button>
            <button type="button" phx-click="request-delete-batch"
                    class="px-2 py-1 flex items-center gap-1.5 text-xs font-medium text-red-600 hover:bg-red-50 hover:text-red-700 rounded-md transition-colors"
                    title="Usuń zaznaczone">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                      d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
              <span class="hidden sm:inline-block">Usuń</span>
            </button>
          </div>
        <% end %>
        <label for={@uploads.images.ref}
               class="cursor-pointer inline-flex items-center px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-md hover:bg-indigo-700 shadow-sm transition-colors">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Dodaj media
        </label>
      </div>
    </div>
    """
  end

  attr :media_items, :list, required: true
  attr :selected_media, :any, required: true

  defp media_grid(assigns) do
    ~H"""
    <%= if Enum.empty?(@media_items) do %>
      <div class="text-center py-24 bg-white rounded-lg border border-gray-200 shadow-sm">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1"
                d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">Brak mediów</h3>
        <p class="mt-1 text-sm text-gray-500">Kiedy dodasz pierwsze zdjęcie w artykułach lub modelach, pojawi się ono tutaj.</p>
      </div>
    <% else %>
      <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-6">
        <%= for item <- @media_items do %>
          <.media_card item={item} selected_media={@selected_media} />
        <% end %>
      </div>
    <% end %>
    """
  end

  attr :item, :map, required: true
  attr :selected_media, :any, required: true

  defp media_card(assigns) do
    ~H"""
    <div class={["group/item relative flex flex-col bg-white rounded-lg border shadow-sm overflow-hidden transition-all",
                 if(MapSet.member?(@selected_media, @item.id),
                   do: "ring-2 ring-indigo-600 border-indigo-600",
                   else: "border-gray-200 hover:shadow-md")]}>
      <div class="aspect-w-1 aspect-h-1 w-full overflow-hidden bg-gray-100 relative">
        <button type="button" phx-click="toggle-select" phx-value-id={@item.id}
                class={["absolute top-2 left-2 p-1 rounded transition-all z-10",
                        if(MapSet.member?(@selected_media, @item.id),
                          do: "opacity-100 text-indigo-600 bg-white shadow-sm",
                          else: "opacity-0 group-hover/item:opacity-100 text-gray-400 bg-white/80 hover:bg-white")]}>
          <%= if MapSet.member?(@selected_media, @item.id) do %>
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
            </svg>
          <% else %>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <rect x="3" y="3" width="18" height="18" rx="2" stroke-width="2" />
            </svg>
          <% end %>
        </button>

        <%= if String.starts_with?(@item.mime_type, "image/") do %>
          <img src={@item.url} alt={@item.file_name} loading="lazy"
               class={["h-full w-full object-cover object-center transition-opacity",
                       if(MapSet.member?(@selected_media, @item.id), do: "opacity-90", else: "group-hover/item:opacity-75")]} />
        <% else %>
          <div class={["flex items-center justify-center h-full w-full bg-gray-50",
                       if(MapSet.member?(@selected_media, @item.id), do: "text-indigo-400", else: "text-gray-400")]}>
            <svg class="h-10 w-10" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
          </div>
        <% end %>

        <button type="button" phx-click="request-delete" phx-value-id={@item.id}
                class="absolute top-2 right-2 bg-white bg-opacity-75 rounded-full p-1.5 text-gray-700 hover:text-red-600 hover:bg-opacity-100 transition-all opacity-0 group-hover/item:opacity-100 shadow-sm z-10">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div class="p-3 flex flex-col flex-1">
        <p class="text-xs font-medium text-gray-900 truncate" title={@item.file_name}><%= @item.file_name %></p>
        <div class="mt-1 flex justify-between items-center text-[10px] text-gray-500">
          <span class="truncate pr-2"><%= @item.mime_type %></span>
          <span><%= format_size(@item.size) %></span>
        </div>
      </div>
    </div>
    """
  end

  defp handle_progress(:images, entry, socket) do
    if entry.done? do
      prefix = socket.assigns.tenant_prefix

      results =
        consume_uploaded_entries(socket, :images, fn %{path: path}, current_entry ->
          process_uploaded_entry(path, current_entry, prefix)
        end)

      socket
      |> MediaUploads.apply_upload_results(results)
      |> refresh_media_list()
    else
      {:noreply, socket}
    end
  end

  defp process_uploaded_entry(path, entry, prefix) do
    case Okovita.Content.process_and_create_media(
           path,
           entry.client_name,
           entry.client_type,
           prefix
         ) do
      {:ok, media} ->
        {:ok, {:ok, media.id}}

      {:error, _reason} ->
        {:ok, {:error, "Wgrywanie pliku #{entry.client_name} nie powiodło się"}}
    end
  end

  defp refresh_media_list(socket) do
    media_items = Content.list_media(socket.assigns.tenant_prefix)
    {:noreply, assign(socket, media_items: media_items)}
  end
end
