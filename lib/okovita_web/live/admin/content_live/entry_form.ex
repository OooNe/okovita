defmodule OkovitaWeb.Admin.ContentLive.EntryForm do
  @moduledoc "Tenant admin: create or edit a content entry with dynamic form from schema_definition."
  use OkovitaWeb, :live_view

  import OkovitaWeb.MediaComponents, only: [media_picker_modal: 1]

  alias Okovita.Content
  alias Okovita.FieldTypes.Image, as: ImageType
  alias Okovita.FieldTypes.ImageGallery, as: GalleryType
  alias Okovita.FieldTypes.Registry

  def mount(%{"model_slug" => slug, "id" => id}, _session, socket) do
    prefix = socket.assigns.tenant_prefix
    model = Content.get_model_by_slug(slug, prefix)
    entry = if model, do: Content.get_entry(id, prefix)

    if model && entry do
      # N+1 Fix: Populate media upfront to avoid DB lookups inside render
      entry = Content.populate_media(entry, model, prefix)

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
          picker_selection: MapSet.new()
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
          picker_selection: MapSet.new()
        )
        |> allow_image_uploads(model)

      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: "/admin/models")}
    end
  end

  # ── Media picker events ───────────────────────────────────────────────────────

  def handle_event("open-media-picker", %{"field" => field, "mode" => mode}, socket) do
    mode_atom = if mode == "single", do: :single, else: :multi

    {:noreply,
     assign(socket, picker_open: %{field: field, mode: mode_atom}, picker_selection: MapSet.new())}
  end

  def handle_event("picker-toggle-select", %{"id" => id}, socket) do
    selection = socket.assigns.picker_selection
    mode = socket.assigns.picker_open.mode

    updated =
      cond do
        MapSet.member?(selection, id) -> MapSet.delete(selection, id)
        mode == :single -> MapSet.new([id])
        true -> MapSet.put(selection, id)
      end

    {:noreply, assign(socket, picker_selection: updated)}
  end

  def handle_event("picker-confirm", %{"field" => field_name}, socket) do
    selected_ids = MapSet.to_list(socket.assigns.picker_selection)
    data = socket.assigns.data
    picker_open = socket.assigns.picker_open

    media_map =
      socket.assigns.media_items
      |> Enum.map(&{&1.id, &1})
      |> Enum.into(%{})

    updated_data =
      case picker_open.mode do
        :single ->
          [selected_id | _] = selected_ids

          value =
            case Map.get(media_map, selected_id) do
              nil ->
                selected_id

              media ->
                %{
                  "id" => media.id,
                  "url" => media.url,
                  "file_name" => media.file_name,
                  "mime_type" => media.mime_type
                }
            end

          Map.put(data, field_name, value)

        :multi ->
          existing = Map.get(data, field_name, []) || []

          existing_ids =
            Enum.map(existing, fn
              %{"media_id" => id} -> id
              %{media_id: id} -> id
              id when is_binary(id) -> id
            end)

          existing_set = MapSet.new(existing_ids)
          new_ids = Enum.reject(selected_ids, &MapSet.member?(existing_set, &1))
          all_ids = existing_ids ++ new_ids

          mapped =
            all_ids
            |> Enum.with_index()
            |> Enum.map(fn {id, i} ->
              base = %{"media_id" => id, "index" => i}

              case Map.get(media_map, id) do
                nil -> base
                media -> Map.merge(base, %{"url" => media.url, "file_name" => media.file_name})
              end
            end)

          Map.put(data, field_name, mapped)
      end

    {:noreply,
     assign(socket,
       data: updated_data,
       picker_open: nil,
       picker_selection: MapSet.new()
     )}
  end

  def handle_event("picker-cancel", _params, socket) do
    {:noreply, assign(socket, picker_open: nil, picker_selection: MapSet.new())}
  end

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

  # ── Validate (SortableJS drag support) ───────────────────────────────────────

  def handle_event("validate", params, socket) do
    model = socket.assigns.model
    data = socket.assigns.data

    updated_data =
      Enum.reduce(model.schema_definition || %{}, data, fn {field_name, def}, acc_data ->
        if def["field_type"] == "image_gallery" do
          sorted_ids_from_dom = Map.get(params, "#{field_name}__existing", [])
          existing_data = Map.get(data, field_name, []) || []
          merged = GalleryType.merge_sort(existing_data, sorted_ids_from_dom)
          Map.put(acc_data, field_name, merged)
        else
          acc_data
        end
      end)

    {:noreply, assign(socket, data: updated_data)}
  end

  # ── Save ──────────────────────────────────────────────────────────────────────

  def handle_event("save", params, socket) do
    prefix = socket.assigns.prefix
    model = socket.assigns.model
    slug = params["slug"] || ""

    # Process uploads for image fields
    upload_results =
      Enum.reduce(model.schema_definition || %{}, %{}, fn {field_name, def}, acc ->
        if def["field_type"] in ["image", "image_gallery"] do
          uploaded_media_results =
            consume_uploaded_entries(
              socket,
              String.to_existing_atom(field_name),
              fn %{path: path}, entry ->
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
              end
            )

          errors =
            Enum.filter(uploaded_media_results, fn
              {:error, _} -> true
              _ -> false
            end)
            |> Enum.map(fn {:error, msg} -> msg end)

          successes =
            Enum.filter(uploaded_media_results, fn
              {:ok, _} -> true
              _ -> false
            end)
            |> Enum.map(fn {:ok, id} -> id end)

          Map.put(acc, field_name, %{successes: successes, errors: errors})
        else
          acc
        end
      end)

    # Flash upload errors
    all_upload_errors =
      upload_results
      |> Map.values()
      |> Enum.flat_map(& &1.errors)

    socket =
      if length(all_upload_errors) > 0 do
        put_flash(socket, :error, Enum.join(all_upload_errors, " | "))
      else
        socket
      end

    upload_data =
      Enum.into(upload_results, %{}, fn {field, result_map} ->
        {field, result_map.successes}
      end)

    # Build final data map: uploaded media takes priority, then params
    upload_data_mapped =
      Enum.reduce(model.schema_definition || %{}, %{}, fn {field_name, def}, acc ->
        if def["field_type"] in ["image", "image_gallery"] do
          uploaded_media_ids = Map.get(upload_data, field_name, [])

          case def["field_type"] do
            "image" ->
              if length(uploaded_media_ids) > 0 do
                Map.put(acc, field_name, hd(uploaded_media_ids))
              else
                id =
                  ImageType.extract_id(Map.get(socket.assigns.data, field_name))

                if id, do: Map.put(acc, field_name, id), else: acc
              end

            "image_gallery" ->
              existing_from_params = Map.get(params, "#{field_name}__existing", [])
              all_ids = existing_from_params ++ uploaded_media_ids

              mapped_ids =
                all_ids
                |> Enum.with_index()
                |> Enum.map(fn {id, i} -> %{"media_id" => id, "index" => i} end)

              Map.put(acc, field_name, mapped_ids)
          end
        else
          acc
        end
      end)

    data =
      model.schema_definition
      |> Enum.into(%{}, fn {field_name, def} ->
        fallback =
          if def["field_type"] in ["image_gallery", "relation_many"], do: [], else: ""

        {field_name,
         Map.get(upload_data_mapped, field_name, Map.get(params, field_name, fallback))}
      end)

    result =
      if socket.assigns.entry do
        Content.update_entry(socket.assigns.entry.id, model.id, %{slug: slug, data: data}, prefix)
      else
        Content.create_entry(model.id, %{slug: slug, data: data}, prefix)
      end

    case result do
      {:ok, _entry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Entry saved!")
         |> push_navigate(
           to: "/admin/tenants/#{socket.assigns.current_tenant.slug}/models/#{model.slug}/entries"
         )}

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
      <h1 class="text-2xl font-bold text-gray-900 mb-8">
        <%= if @entry, do: "Edit Entry", else: "New Entry" %> — <span class="text-indigo-600"><%= @model.name %></span>
      </h1>

      <form phx-submit="save" phx-change="validate" class="space-y-6">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Slug</label>
          <input type="text" name="slug" value={@slug} required
            class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm
                   placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500
                   sm:text-sm" />
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
          <button type="submit"
            class="inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm
                   font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none
                   focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors">
            Save Entry
          </button>
          <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{@model.slug}/entries"}
             class="text-sm font-medium text-gray-600 hover:text-gray-900 transition-colors">
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

  # Builds the assigns map to pass to an editor component for a given field.
  defp build_field_assigns(field_name, field_def, assigns) do
    field_atom = String.to_existing_atom(field_name)
    upload = Map.get(assigns, :uploads, %{})[field_atom]
    raw_value = Map.get(assigns.data, field_name)

    base = %{
      name: field_name,
      value: raw_value
    }

    case field_def["field_type"] do
      "image" ->
        Map.merge(base, %{
          upload: upload,
          media_value: %{
            id: ImageType.extract_id(raw_value),
            url: ImageType.extract_url(raw_value)
          }
        })

      "image_gallery" ->
        Map.merge(base, %{
          upload: upload,
          value: GalleryType.normalize(raw_value)
        })

      "enum" ->
        Map.merge(base, %{
          options: field_def["one_of"] || []
        })

      "relation" ->
        Map.merge(base, %{
          options: Map.get(assigns.relation_options, field_name, [])
        })

      "relation_many" ->
        Map.merge(base, %{
          value: raw_value || [],
          options: Map.get(assigns.relation_options, field_name, [])
        })

      _ ->
        base
    end
  end

  defp allow_image_uploads(socket, model) do
    Enum.reduce(model.schema_definition || %{}, socket, fn {field_name, def}, acc_socket ->
      case def["field_type"] do
        "image" ->
          # String.to_atom/1 here creates the atom for the first time at mount;
          # String.to_existing_atom/1 is then safe in subsequent event handlers.
          allow_upload(acc_socket, String.to_atom(field_name),
            accept: ~w(.jpg .jpeg .png .gif .webp),
            max_entries: 1
          )

        "image_gallery" ->
          allow_upload(acc_socket, String.to_atom(field_name),
            accept: ~w(.jpg .jpeg .png .gif .webp),
            max_entries: 20
          )

        _ ->
          acc_socket
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
      if def["field_type"] in ["relation", "relation_many"] and def["target_model"] do
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
