defmodule OkovitaWeb.Admin.ContentLive.EntryForm do
  @moduledoc "Tenant admin: create or edit a content entry with dynamic form from schema_definition."
  use OkovitaWeb, :live_view

  alias Okovita.Content

  def mount(%{"model_slug" => slug, "id" => id}, _session, socket) do
    prefix = socket.assigns.tenant_prefix
    model = Content.get_model_by_slug(slug, prefix)
    entry = if model, do: Content.get_entry(id, prefix)

    if model && entry do
      # N+1 Fix: Populate media upfront to avoid DB lookups inside render_field_input
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
          relation_options: load_relation_options(model, prefix)
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
          relation_options: load_relation_options(model, prefix)
        )
        |> allow_image_uploads(model)

      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: "/admin/models")}
    end
  end

  def handle_event("save", params, socket) do
    prefix = socket.assigns.prefix
    model = socket.assigns.model
    slug = params["slug"] || ""

    # Process uploads for image fields
    upload_results =
      Enum.reduce(model.schema_definition || %{}, %{}, fn {field_name, def}, acc ->
        if def["field_type"] in ["image", "image_gallery"] do
          uploaded_media_results =
            consume_uploaded_entries(socket, String.to_atom(field_name), fn %{path: path},
                                                                            entry ->
              case Okovita.Media.Uploader.upload(path, entry.client_name, entry.client_type) do
                {:ok, attrs} ->
                  case Okovita.Content.create_media(attrs, prefix) do
                    {:ok, media} -> {:ok, {:ok, media.id}}
                    _ -> {:ok, {:error, "Failed to create media record for #{entry.client_name}"}}
                  end

                {:error, _reason} ->
                  {:ok, {:error, "Failed to upload #{entry.client_name} to S3"}}

                _ ->
                  {:ok, {:error, "Failed to upload #{entry.client_name}"}}
              end
            end)

          # separate successes from errors
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

    # Flash errors if any S3 upload failed
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

    # Extract just the valid IDs mapped for data
    upload_data =
      Enum.into(upload_results, %{}, fn {field, result_map} ->
        {field, result_map.successes}
      end)

    # Process field assignments exactly as before using the filtered upload_data list
    upload_data_mapped =
      Enum.reduce(model.schema_definition || %{}, %{}, fn {field_name, def}, acc ->
        if def["field_type"] in ["image", "image_gallery"] do
          uploaded_media_ids = Map.get(upload_data, field_name, [])

          case def["field_type"] do
            "image" ->
              if length(uploaded_media_ids) > 0 do
                Map.put(acc, field_name, hd(uploaded_media_ids))
              else
                # Keep the existing value if no new file is uploaded
                existing = Map.get(socket.assigns.data, field_name)
                # existing is the populated media object or a raw string URL from older versions
                id =
                  case existing do
                    %{id: id} -> id
                    %{"id" => id} -> id
                    id when is_binary(id) -> id
                    _ -> ""
                  end

                if id != "", do: Map.put(acc, field_name, id), else: acc
              end

            "image_gallery" ->
              # Existing items might come from params due to hidden inputs, or from assigns data.
              # We prioritize params (which represents the grid state after removals and sorting)
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

    # Collect field values from params and merge uploaded URLs
    data =
      model.schema_definition
      |> Enum.into(%{}, fn {field_name, def} ->
        # Overwrite param values with uploaded URLs if they exist for image fields
        # Fallback for empty image gallery in params
        fallback = if def["field_type"] == "image_gallery", do: [], else: ""

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

  def handle_event("remove-gallery-image", %{"name" => name, "index" => index_str}, socket) do
    index = String.to_integer(index_str)

    data = socket.assigns.data
    current_images = Map.get(data, name, []) || []

    updated_images =
      current_images
      |> Enum.with_index()
      |> Enum.map(fn
        {id, idx} when is_binary(id) -> %{"media_id" => id, "index" => idx}
        {map, _} when is_map(map) -> map
      end)
      |> List.delete_at(index)
      |> Enum.sort_by(&(&1["index"] || 0))
      |> Enum.with_index()
      |> Enum.map(fn {item, i} -> Map.put(item, "index", i) end)

    updated_data = Map.put(data, name, updated_images)

    # We need to explicitly trigger an update to the struct/map for the form to re-render.
    {:noreply, assign(socket, data: updated_data)}
  end

  def handle_event("cancel-upload", %{"ref" => ref, "name" => name}, socket) do
    {:noreply, cancel_upload(socket, String.to_atom(name), ref)}
  end

  def handle_event("validate", params, socket) do
    # During validate, preserve the ordered state of gallery inputs to support SortableJS drag & drop dragging re-renders
    model = socket.assigns.model
    data = socket.assigns.data

    updated_data =
      Enum.reduce(model.schema_definition || %{}, data, fn {field_name, def}, acc_data ->
        if def["field_type"] == "image_gallery" do
          sorted_ids_from_dom = Map.get(params, "#{field_name}__existing", [])
          existing_data = Map.get(data, field_name, []) || []

          mapped_ids =
            sorted_ids_from_dom
            |> Enum.with_index()
            |> Enum.map(fn {id, i} ->
              existing_item =
                Enum.find(existing_data, fn item ->
                  (is_map(item) && item["media_id"] == id) || (is_binary(item) && item == id)
                end)

              merged =
                case existing_item do
                  nil -> %{}
                  map when is_map(map) -> map
                  bin when is_binary(bin) -> %{}
                end

              Map.merge(merged, %{"media_id" => id, "index" => i})
            end)

          Map.put(acc_data, field_name, mapped_ids)
        else
          acc_data
        end
      end)

    {:noreply, assign(socket, data: updated_data)}
  end

  defp allow_image_uploads(socket, model) do
    Enum.reduce(model.schema_definition || %{}, socket, fn {field_name, def}, acc_socket ->
      case def["field_type"] do
        "image" ->
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

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto bg-white rounded-xl shadow-sm ring-1 ring-gray-900/5 p-8">
      <h1 class="text-2xl font-bold text-gray-900 mb-8">
        <%= if @entry, do: "Edit Entry", else: "New Entry" %> — <span class="text-indigo-600"><%= @model.name %></span>
      </h1>

      <form phx-submit="save" phx-change="validate" class="space-y-6">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Slug</label>
          <input type="text" name="slug" value={@slug} required class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
        </div>

        <%= for {field_name, def} <- @model.schema_definition do %>
          <div>
            <label for={field_name} class="block text-sm font-medium text-gray-700 mb-1">
              <%= def["label"] %>
              <span :if={def["required"]} class="text-red-500">*</span>
            </label>
            <%= render_field_input(field_name, def, @data, @relation_options, @uploads, @prefix) %>

            <%= for err <- (@errors[String.to_atom(field_name)] || []) do %>
              <p class="mt-2 text-sm text-red-600"><%= err %></p>
            <% end %>
          </div>
        <% end %>

        <div class="mt-8 pt-6 border-t border-gray-200 flex items-center space-x-4">
          <button type="submit" class="inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors">Save Entry</button>
          <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{@model.slug}/entries"} class="text-sm font-medium text-gray-600 hover:text-gray-900 transition-colors">Cancel</a>
        </div>
      </form>
    </div>
    """
  end

  # Unified render_field_input mapping
  defp render_field_input(
         name,
         %{"field_type" => "image"},
         data,
         _relation_options,
         uploads,
         _prefix
       ) do
    raw_value = Map.get(data, name, "")

    media_url =
      case raw_value do
        %{url: url} -> url
        %{"url" => url} -> url
        _ -> nil
      end

    value =
      case raw_value do
        %{id: id} -> id
        %{"id" => id} -> id
        id when is_binary(id) -> id
        _ -> ""
      end

    assigns = %{name: name, value: value, uploads: uploads, media_url: media_url}

    ~H"""
    <div class="mt-2" phx-drop-target={@uploads[String.to_atom(@name)].ref}>
      <%= if @media_url do %>
        <div class="mb-4 relative w-32 h-32 rounded-lg border border-gray-200 overflow-hidden bg-gray-50 flex items-center justify-center">
          <img src={@media_url} alt="Uploaded Image" class="object-cover w-full h-full" />
        </div>
      <% end %>

      <!-- LiveUpload Input -->
      <div class="flex items-center justify-center w-full">
        <label for={@uploads[String.to_atom(@name)].ref} class="flex flex-col items-center justify-center w-full h-32 border-2 border-gray-300 border-dashed rounded-lg cursor-pointer bg-gray-50 hover:bg-gray-100">
          <div class="flex flex-col items-center justify-center pt-5 pb-6">
            <svg class="w-8 h-8 mb-4 text-gray-500" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 20 16">
              <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 13h3a3 3 0 0 0 0-6h-.025A5.56 5.56 0 0 0 16 6.5 5.5 5.5 0 0 0 5.207 5.021C5.137 5.017 5.071 5 5 5a4 4 0 0 0 0 8h2.167M10 15V6m0 0L8 8m2-2 2 2"/>
            </svg>
            <p class="mb-2 text-sm text-gray-500"><span class="font-semibold">Click to upload</span> or drag and drop</p>
            <p class="text-xs text-gray-500">SVG, PNG, JPG or WEBP</p>
          </div>
          <.live_file_input upload={@uploads[String.to_atom(@name)]} class="hidden" />
        </label>
      </div>

      <!-- Upload Entries Preview & Progress -->
      <%= for entry <- @uploads[String.to_atom(@name)].entries do %>
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
          <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} phx-value-name={@name} class="text-gray-400 hover:text-red-500 transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
          </button>
        </div>

        <%= for err <- upload_errors(@uploads[String.to_atom(@name)], entry) do %>
          <p class="mt-1 text-sm text-red-600"><%= error_to_string(err) %></p>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp render_field_input(
         name,
         %{"field_type" => "image_gallery"},
         data,
         _relation_options,
         uploads,
         prefix
       ) do
    raw_value = Map.get(data, name, []) || []

    normalized_value =
      raw_value
      |> Enum.with_index()
      |> Enum.map(fn
        {id, idx} when is_binary(id) -> %{"media_id" => id, "index" => idx}
        {map, _} when is_map(map) -> map
      end)
      |> Enum.sort_by(&(&1["index"] || 0))

    assigns = %{name: name, value: normalized_value, uploads: uploads, prefix: prefix}

    ~H"""
    <div class="mt-2 flex flex-col space-y-4" phx-drop-target={@uploads[String.to_atom(@name)].ref}>
      <!-- Existing Images Gallery -->
      <%= if length(@value) > 0 do %>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4" phx-hook="Sortable" id={"sortable-#{@name}"}>
          <%= for item <- Enum.sort_by(@value, & &1["index"]) do %>
            <div class="relative group w-full h-32 rounded-lg border border-gray-200 overflow-hidden bg-gray-50 flex items-center justify-center cursor-move">
              <%= if item["url"] || item[:url] do %>
                <img src={item["url"] || item[:url]} alt="Gallery Image" class="object-cover w-full h-full pointer-events-none" />
              <% end %>
              <!-- Hidden input to keep existing URLs in form data -->
              <input type="hidden" name={"#{@name}__existing[]"} value={item["media_id"]} />
              <button type="button" phx-click="remove-gallery-image" phx-value-name={@name} phx-value-index={item["index"]} class="absolute top-2 right-2 bg-white bg-opacity-75 rounded-full p-1 text-gray-700 hover:text-red-500 hover:bg-opacity-100 transition-all opacity-0 group-hover:opacity-100">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
              </button>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- LiveUpload Input -->
      <div class="flex items-center justify-center w-full">
        <label for={@uploads[String.to_atom(@name)].ref} class="flex flex-col items-center justify-center w-full h-32 border-2 border-gray-300 border-dashed rounded-lg cursor-pointer bg-gray-50 hover:bg-gray-100">
          <div class="flex flex-col items-center justify-center pt-5 pb-6">
            <svg class="w-8 h-8 mb-4 text-gray-500" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 20 16">
              <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 13h3a3 3 0 0 0 0-6h-.025A5.56 5.56 0 0 0 16 6.5 5.5 5.5 0 0 0 5.207 5.021C5.137 5.017 5.071 5 5 5a4 4 0 0 0 0 8h2.167M10 15V6m0 0L8 8m2-2 2 2"/>
            </svg>
            <p class="mb-2 text-sm text-gray-500"><span class="font-semibold">Click to upload</span> or drag and drop</p>
            <p class="text-xs text-gray-500">Add up to 20 images</p>
          </div>
          <.live_file_input upload={@uploads[String.to_atom(@name)]} class="hidden" />
        </label>
      </div>

      <!-- Upload Entries Preview & Progress -->
      <%= if length(@uploads[String.to_atom(@name)].entries) > 0 do %>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-4">
          <%= for entry <- @uploads[String.to_atom(@name)].entries do %>
            <div class="relative w-full h-32 rounded-lg border border-gray-200 overflow-hidden shadow-sm">
              <.live_img_preview entry={entry} class="object-cover w-full h-full" />
              <div class="absolute bottom-0 left-0 right-0 bg-white bg-opacity-90 p-2">
                <div class="w-full bg-gray-200 rounded-full h-1.5">
                  <div class="bg-indigo-600 h-1.5 rounded-full" style={"width: #{entry.progress}%"}></div>
                </div>
              </div>
              <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} phx-value-name={@name} class="absolute top-2 right-2 bg-white bg-opacity-75 rounded-full p-1 text-gray-700 hover:text-red-500 transition-colors">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
              </button>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= for entry <- @uploads[String.to_atom(@name)].entries do %>
        <%= for err <- upload_errors(@uploads[String.to_atom(@name)], entry) do %>
          <p class="mt-1 text-sm text-red-600 truncate"><%= entry.client_name %>: <%= error_to_string(err) %></p>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp render_field_input(
         name,
         %{"field_type" => "textarea"},
         data,
         _relation_options,
         _uploads,
         _prefix
       ) do
    assigns = %{name: name, value: Map.get(data, name, "")}

    ~H"""
    <textarea name={@name} rows="5" class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm font-sans"><%= @value %></textarea>
    """
  end

  defp render_field_input(
         name,
         %{"field_type" => "boolean"},
         data,
         _relation_options,
         _uploads,
         _prefix
       ) do
    assigns = %{name: name, checked: Map.get(data, name) in [true, "true"]}

    ~H"""
    <input type="checkbox" name={@name} value="true" checked={@checked} class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded cursor-pointer" />
    """
  end

  defp render_field_input(
         name,
         %{"field_type" => "enum", "one_of" => options},
         data,
         _relation_options,
         _uploads,
         _prefix
       ) do
    assigns = %{name: name, value: Map.get(data, name, ""), options: options}

    ~H"""
    <select name={@name} class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md bg-white">
      <option value="">Select...</option>
      <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
    </select>
    """
  end

  defp render_field_input(
         name,
         %{"field_type" => type},
         _data,
         _relation_options,
         _uploads,
         _prefix
       )
       when type in ["list", "map"] do
    assigns = %{name: name, type: type}

    ~H"""
    <div class="p-4 bg-gray-50 border border-gray-200 rounded-md text-sm text-gray-500 italic">
      Field type '<%= @type %>' is not currently supported in the admin UI.
    </div>
    """
  end

  defp render_field_input(
         name,
         %{"field_type" => "relation"},
         data,
         relation_options,
         _uploads,
         _prefix
       ) do
    assigns = %{
      name: name,
      value: Map.get(data, name, ""),
      options: Map.get(relation_options, name, [])
    }

    ~H"""
    <select name={@name} class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md bg-white">
      <option value="">Select an entry...</option>
      <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
    </select>
    """
  end

  defp render_field_input(
         name,
         %{"field_type" => type},
         data,
         _relation_options,
         _uploads,
         _prefix
       )
       when type in ["integer", "number"] do
    assigns = %{
      name: name,
      value: Map.get(data, name, ""),
      type: if(type == "integer", do: "number", else: "number"),
      step: if(type == "integer", do: "1", else: "any")
    }

    ~H"""
    <input type={@type} step={@step} name={@name} value={@value} class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
    """
  end

  defp render_field_input(
         name,
         %{"field_type" => "date"},
         data,
         _relation_options,
         _uploads,
         _prefix
       ) do
    assigns = %{name: name, value: Map.get(data, name, "")}

    ~H"""
    <input type="date" name={@name} value={@value} class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
    """
  end

  defp render_field_input(
         name,
         %{"field_type" => "datetime"},
         data,
         _relation_options,
         _uploads,
         _prefix
       ) do
    assigns = %{name: name, value: Map.get(data, name, "")}

    ~H"""
    <input type="datetime-local" name={@name} value={@value} class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
    """
  end

  defp render_field_input(name, _field_def, data, _relation_options, _uploads, _prefix) do
    assigns = %{name: name, value: Map.get(data, name, "")}

    ~H"""
    <input type="text" name={@name} value={@value} class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
    """
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp load_relation_options(model, prefix) do
    Enum.reduce(model.schema_definition || %{}, %{}, fn {field_name, def}, acc ->
      if def["field_type"] == "relation" and def["target_model"] do
        target_model = Content.get_model_by_slug(def["target_model"], prefix)

        if target_model do
          entries = Content.list_entries(target_model.id, prefix)
          # We use entry.slug as the label and entry.id as the value for the relation
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
