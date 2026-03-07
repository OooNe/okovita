defmodule OkovitaWeb.Admin.ContentLive.EntryForm do
  @moduledoc "Tenant admin: create or edit a content entry with dynamic form from schema_definition."
  use OkovitaWeb, :live_view

  import OkovitaWeb.MediaComponents, only: [media_picker_modal: 1]

  alias Okovita.Content
  alias Okovita.FieldTypes.ImageGallery, as: GalleryType
  alias Okovita.FieldTypes.Registry
  alias OkovitaWeb.Admin.ContentLive.EntryForm.PickerHandler
  alias OkovitaWeb.Admin.ContentLive.EntryForm.SaveHandler

  def mount(%{"model_slug" => slug, "id" => id}, _session, socket) do
    prefix = socket.assigns.tenant_prefix
    model = Content.get_model_by_slug(slug, prefix)
    entry = if model, do: Content.get_entry(id, prefix)

    if model && entry do
      # N+1 Fix: Populate media upfront to avoid DB lookups inside render
      entry = Content.populate(entry, model, prefix, populate: :all)

      socket =
        socket
        |> assign(
          model: model,
          entry: entry,
          data: entry.data,
          slug: entry.slug,
          prefix: prefix,
          errors: %{},
          relation_options: load_relation_options(model, prefix),
          media_items: Content.list_media(prefix),
          picker_open: nil,
          picker_selection: MapSet.new(),
          manual_slug: false,
          active_field_modal: nil
        )
        |> allow_image_uploads(model)

      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: "/admin/models")}
    end
  end

  def mount(%{"model_slug" => slug}, _session, socket) do
    prefix = socket.assigns.tenant_prefix
    model = Content.get_model_by_slug(slug, prefix)

    if model do
      socket =
        socket
        |> assign(
          model: model,
          entry: nil,
          data: %{},
          slug: "",
          prefix: prefix,
          errors: %{},
          relation_options: load_relation_options(model, prefix),
          media_items: Content.list_media(prefix),
          picker_open: nil,
          picker_selection: MapSet.new(),
          manual_slug: false,
          active_field_modal: nil
        )
        |> allow_image_uploads(model)

      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: "/admin/models")}
    end
  end

  # ── Modal Events ──────────────────────────────────────────────────────────────

  def handle_event("open-field-modal", %{"field" => field}, socket) do
    {:noreply, assign(socket, active_field_modal: field)}
  end

  def handle_event("close-field-modal", _params, socket) do
    {:noreply, assign(socket, active_field_modal: nil)}
  end

  # ── Media picker events ───────────────────────────────────────────────────────

  def handle_event("open-media-picker", %{"field" => field, "mode" => mode}, socket),
    do: PickerHandler.open(socket, field, mode)

  def handle_event("picker-toggle-select", %{"id" => id}, socket),
    do: PickerHandler.toggle(socket, id)

  def handle_event("picker-confirm", %{"field" => field_name}, socket),
    do: PickerHandler.confirm(socket, field_name)

  def handle_event("picker-cancel", _params, socket),
    do: PickerHandler.cancel(socket)

  # ── Gallery events ────────────────────────────────────────────────────────────

  def handle_event("remove-gallery-image", %{"name" => name, "index" => index_str}, socket) do
    index = String.to_integer(index_str)
    data = socket.assigns.data
    current_images = Map.get(data, name, []) || []
    updated_images = GalleryType.remove_item(current_images, index)
    {:noreply, assign(socket, data: Map.put(data, name, updated_images))}
  end

  # ── Upload events ─────────────────────────────────────────────────────────────

  def handle_event("cancel-upload", %{"ref" => ref, "name" => name}, socket) do
    {:noreply, cancel_upload(socket, String.to_existing_atom(name), ref)}
  end

  # ── Slug Toggle ───────────────────────────────────────────────────────────────

  def handle_event("toggle-manual-slug", _params, socket) do
    {:noreply, assign(socket, manual_slug: not socket.assigns.manual_slug)}
  end

  # ── Validate (SortableJS drag support) ───────────────────────────────────────

  def handle_event("validate", params, socket) do
    model = socket.assigns.model
    data = socket.assigns.data
    entry = socket.assigns.entry

    updated_data =
      Enum.reduce(model.schema_definition || %{}, data, fn {field_name, def}, acc_data ->
        if def["field_type"] == "image_gallery" do
          if Map.has_key?(params, "#{field_name}__existing") do
            sorted_ids_from_dom = Map.get(params, "#{field_name}__existing", [])
            existing_data = Map.get(data, field_name, []) || []
            merged = GalleryType.merge_sort(existing_data, sorted_ids_from_dom)
            Map.put(acc_data, field_name, merged)
          else
            acc_data
          end
        else
          acc_data
        end
      end)

    slug =
      if is_nil(entry) and model.slug_field and not socket.assigns.manual_slug do
        target_value = Map.get(params, model.slug_field, "")
        {:ok, base_slug} = Okovita.Pipeline.Sync.Slugify.apply(to_string(target_value), nil)
        base_slug
      else
        Map.get(params, "slug", socket.assigns.slug)
      end

    {:noreply, assign(socket, data: updated_data, slug: slug)}
  end

  # ── Save ──────────────────────────────────────────────────────────────────────

  def handle_event("save", %{"action" => action} = params, socket) do
    prefix = socket.assigns.prefix
    model = socket.assigns.model
    slug = params["slug"] || ""

    # consume_uploaded_entries/3 is a LiveView macro — must stay in this module.
    raw_upload_results =
      Enum.reduce(model.schema_definition || %{}, %{}, fn {field_name, def}, acc ->
        if Registry.upload_config(def["field_type"]) != nil do
          results =
            consume_uploaded_entries(socket, String.to_existing_atom(field_name), fn
              %{path: path}, entry ->
                case Okovita.Media.Uploader.upload(path, entry.client_name, entry.client_type) do
                  {:ok, attrs} ->
                    case Okovita.Content.create_media(attrs, prefix) do
                      {:ok, media} ->
                        {:ok, {:ok, media.id}}

                      _ ->
                        {:ok, {:error, "Failed to create media record for #{entry.client_name}"}}
                    end

                  {:error, _reason} ->
                    {:ok, {:error, "Failed to upload #{entry.client_name} to S3"}}

                  _ ->
                    {:ok, {:error, "Failed to upload #{entry.client_name}"}}
                end
            end)

          Map.put(acc, field_name, results)
        else
          acc
        end
      end)

    {socket, upload_results} = SaveHandler.collect_results(socket, raw_upload_results)

    data =
      SaveHandler.build_data(model.schema_definition, upload_results, params, socket.assigns.data)

    result =
      if socket.assigns.entry do
        Content.update_entry(socket.assigns.entry.id, model.id, %{slug: slug, data: data}, prefix)
      else
        Content.create_entry(model.id, %{slug: slug, data: data}, prefix)
      end

    case result do
      {:ok, entry} ->
        socket = socket |> put_flash(:info, "Entry saved!")

        if action == "save_and_exit" do
          {:noreply,
           push_navigate(
             socket,
             to:
               "/admin/tenants/#{socket.assigns.current_tenant.slug}/models/#{model.slug}/entries"
           )}
        else
          {:noreply,
           push_navigate(
             socket,
             to:
               "/admin/tenants/#{socket.assigns.current_tenant.slug}/models/#{model.slug}/entries/#{entry.id}/edit"
           )}
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_errors(changeset)
        {:noreply, assign(socket, errors: errors, data: data, slug: slug)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to save entry")}
    end
  end

  # ── Render ────────────────────────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto bg-white rounded-xl shadow-sm ring-1 ring-gray-900/5 p-8">
      <h1 class="text-2xl font-bold text-gray-900 mb-6">
        <%= if @entry, do: "Edytuj wpis", else: "Nowy wpis" %> — <span class="text-indigo-600"><%= @model.name %></span>
      </h1>

      <%= if @entry do %>
        <div class="border-b border-gray-200 mb-8">
          <nav class="-mb-px flex space-x-8" aria-label="Tabs">
            <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{@model.slug}/entries/#{@entry.id}/edit"}
               class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm border-indigo-500 text-indigo-600"
               aria-current="page">
              Edycja
            </a>

            <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{@model.slug}/entries/#{@entry.id}/history"}
               class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 transition-colors">
              Historia
            </a>
          </nav>
        </div>
      <% end %>

      <form phx-submit="save" phx-change="validate" class="space-y-6">
        <div>
          <div class="flex items-center justify-between mb-1">
            <label class="block text-sm font-medium text-gray-700">Slug</label>
            <%= if @model.slug_field do %>
              <button type="button" phx-click="toggle-manual-slug" class="text-xs text-indigo-600 hover:text-indigo-800 focus:outline-none flex items-center gap-1 transition-colors">
                <%= if @manual_slug do %>
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-4 h-4"><path fill-rule="evenodd" d="M15.312 11.424a5.5 5.5 0 01-9.201 2.466l-.312-.311h2.433a.75.75 0 000-1.5H3.989a.75.75 0 00-.75.75v4.242a.75.75 0 001.5 0v-2.43l.31.31a7 7 0 0011.712-3.138.75.75 0 00-1.449-.39zm1.23-3.723a.75.75 0 00.219-.53V2.929a.75.75 0 00-1.5 0V5.36l-.31-.31A7 7 0 003.239 8.188a.75.75 0 101.448.389A5.5 5.5 0 0113.89 6.11l.311.31h-2.432a.75.75 0 000 1.5h4.243a.75.75 0 00.53-.219z" clip-rule="evenodd" /></svg>
                  Auto-generate
                <% else %>
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-4 h-4"><path d="M2.695 14.763l-1.262 3.154a.5.5 0 00.65.65l3.155-1.262a4 4 0 001.343-.885L17.5 5.5a2.121 2.121 0 00-3-3L3.58 13.42a4 4 0 00-.885 1.343z" /></svg>
                  Edit manually
                <% end %>
              </button>
            <% end %>
          </div>

          <input type="text" name="slug" value={@slug} required={unless @model.slug_field && !@manual_slug, do: true, else: false}
            readonly={if @model.slug_field && !@manual_slug, do: true, else: false}
            class={["appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm sm:text-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500",
                    if(@model.slug_field && !@manual_slug, do: "bg-gray-100 cursor-not-allowed text-gray-500", else: "placeholder-gray-400")]} />

          <%= if @model.slug_field && !@manual_slug do %>
            <p class="mt-1 text-xs text-gray-500">Slug is automatically generated based on the <span class="font-semibold"><%= @model.slug_field %></span> field.</p>
          <% end %>
        </div>

        <%= for {field_name, field_def} <- @model.schema_definition do %>
          <div>
            <label for={field_name} class="block text-sm font-medium text-gray-700 mb-1">
              <%= field_def["label"] %>
              <span :if={field_def["required"]} class="text-red-500">*</span>
            </label>

            <%= case Registry.editor_for(field_def["field_type"]) do %>
              <% nil -> %>
                <div class="p-4 bg-gray-50 border border-gray-200 rounded-md text-sm text-gray-500 italic">
                  Field type '<%= field_def["field_type"] %>' is not supported in the admin UI.
                </div>
              <% editor_module -> %>
                <%= Phoenix.LiveView.TagEngine.component(
                      &editor_module.render/1,
                      build_field_assigns(field_name, field_def, assigns),
                      {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
                    ) %>
            <% end %>

            <%= for err <- (@errors[String.to_atom(field_name)] || []) do %>
              <p class="mt-2 text-sm text-red-600"><%= err %></p>
            <% end %>
          </div>
        <% end %>

        <div class="mt-8 pt-6 border-t border-gray-200 flex items-center space-x-4">
          <button type="submit" name="action" value="save"
            class="inline-flex justify-center py-2 px-4 border border-gray-300 shadow-sm text-sm
                   font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none
                   focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors">
            Save
          </button>
          <button type="submit" name="action" value="save_and_exit"
            class="inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm
                   font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none
                   focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors">
            Save and Exit
          </button>
          <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{@model.slug}/entries"}
             class="text-sm font-medium text-gray-600 hover:text-gray-900 transition-colors pl-2">
            Cancel
          </a>
        </div>
      </form>

      <.media_picker_modal
        picker_open={@picker_open}
        picker_selection={@picker_selection}
        media_items={@media_items} />
    </div>
    """
  end

  # ── Private ───────────────────────────────────────────────────────────────────

  # Builds the assigns map passed to an editor component.
  # Base is %{name: field_name, value: raw_value}; extra assigns come from Registry.
  defp build_field_assigns(field_name, field_def, assigns) do
    base = %{
      name: field_name,
      value: Map.get(assigns.data, field_name),
      active_field_modal: assigns[:active_field_modal]
    }

    extra = Registry.form_assigns(field_def["field_type"], field_name, field_def, assigns)
    Map.merge(base, extra)
  end

  defp allow_image_uploads(socket, model) do
    Enum.reduce(model.schema_definition || %{}, socket, fn {field_name, def}, acc_socket ->
      case Registry.upload_config(def["field_type"]) do
        nil ->
          acc_socket

        {max_entries, accept} ->
          # String.to_atom/1 is intentional at mount time to create the atom;
          # String.to_existing_atom/1 is then safe in event handlers.
          allow_upload(acc_socket, String.to_atom(field_name),
            accept: accept,
            max_entries: max_entries
          )
      end
    end)
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r/%{(\w+)}/, msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp load_relation_options(model, prefix) do
    Enum.reduce(model.schema_definition || %{}, %{}, fn {field_name, def}, acc ->
      if Registry.targets_entry?(def["field_type"]) and def["target_model"] do
        target_model = Content.get_model_by_slug(def["target_model"], prefix)

        if target_model do
          entries = Content.list_entries(target_model.id, prefix)
          options = Enum.map(entries, fn e -> {e.slug, e.id} end)
          Map.put(acc, field_name, options)
        else
          acc
        end
      else
        acc
      end
    end)
  end
end
