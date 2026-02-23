defmodule OkovitaWeb.Admin.ContentLive.ModelBuilder do
  @moduledoc "Tenant admin: create and edit content models with dynamic field definitions."
  use OkovitaWeb, :live_view

  alias Okovita.Content
  alias Okovita.FieldTypes.Registry

  def mount(%{"id" => id}, _session, socket) do
    prefix = socket.assigns.tenant_prefix
    model = Content.get_model(id, prefix)
    available_models = Content.list_models(prefix)

    if model do
      {:ok,
       assign(socket,
         model: model,
         form_data: %{slug: model.slug, name: model.name},
         fields: schema_to_field_list(model.schema_definition),
         field_types: Registry.registered_types(),
         available_models: available_models,
         prefix: prefix
       )}
    else
      {:ok,
       push_navigate(socket, to: "/admin/tenants/#{socket.assigns.current_tenant.slug}/models")}
    end
  end

  def mount(_params, _session, socket) do
    prefix = socket.assigns.tenant_prefix
    available_models = Content.list_models(prefix)

    {:ok,
     assign(socket,
       model: nil,
       form_data: %{slug: "", name: ""},
       fields: [],
       field_types: Registry.registered_types(),
       available_models: available_models,
       prefix: prefix
     )}
  end

  def handle_event("add-field", _params, socket) do
    new_field = %{
      "id" => Ecto.UUID.generate(),
      "key" => "",
      "field_type" => "text",
      "label" => "",
      "required" => false
    }

    fields = socket.assigns.fields ++ [new_field]
    {:noreply, assign(socket, fields: fields)}
  end

  def handle_event("remove-field", %{"id" => id}, socket) do
    fields = Enum.reject(socket.assigns.fields, &(&1["id"] == id))
    {:noreply, assign(socket, fields: fields)}
  end

  def handle_event("update-form", _params, socket) do
    # Only triggered if form changes outside of field-specific handlers
    {:noreply, socket}
  end

  def handle_event("update-field", params, socket) do
    {id, attr, value} =
      case Map.get(params, "_target") do
        ["fields", target_id, target_attr] ->
          {target_id, target_attr, get_in(params, ["fields", target_id, target_attr])}

        _ ->
          {params["id"], params["attr"], params["value"]}
      end

    if id && attr && value != nil do
      update_field_in_socket(socket, id, attr, value)
    else
      {:noreply, socket}
    end
  end

  def handle_event("save", params, socket) do
    prefix = socket.assigns.prefix
    fields = socket.assigns.fields

    current_model_slug = if socket.assigns.model, do: socket.assigns.model.slug, else: nil
    errors_list = validate_fields(fields, current_model_slug)

    if Enum.empty?(errors_list) do
      schema_definition =
        Enum.reduce(fields, %{}, fn f, acc ->
          Map.put(acc, f["key"], Map.take(f, ["label", "field_type", "required", "target_model"]))
        end)

      attrs = %{
        slug: params["slug"],
        name: params["name"],
        schema_definition: schema_definition
      }

      result =
        if socket.assigns.model do
          Content.update_model(socket.assigns.model.id, attrs, prefix)
        else
          Content.create_model(attrs, prefix)
        end

      case result do
        {:ok, _model} ->
          {:noreply,
           socket
           |> put_flash(:info, "Model saved!")
           |> push_navigate(to: "/admin/tenants/#{socket.assigns.current_tenant.slug}/models")}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "Error: #{inspect(changeset.errors)}")}
      end
    else
      {:noreply,
       put_flash(socket, :error, "Validation failed: " <> Enum.join(errors_list, " | "))}
    end
  end

  defp update_field_in_socket(socket, id, attr, value) do
    value = if attr == "required", do: value == "true", else: value

    fields =
      Enum.map(socket.assigns.fields, fn
        %{"id" => ^id} = f -> Map.put(f, attr, value)
        f -> f
      end)

    {:noreply, assign(socket, fields: fields)}
  end

  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto bg-white rounded-xl shadow-sm ring-1 ring-gray-900/5 p-8 my-8">
      <div class="border-b border-gray-200 pb-5 mb-8">
        <h1 class="text-2xl font-bold leading-tight text-gray-900">
          <%= if @model, do: "Edit Model", else: "New Model" %>
        </h1>
      </div>

      <form phx-change="update-form" phx-submit="save" id="model-form" class="space-y-8">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 pb-8 border-b border-gray-200">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Name <span class="text-red-500">*</span></label>
            <input type="text" name="name" value={@form_data[:name]} required class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Slug <span class="text-red-500">*</span></label>
            <input type="text" name="slug" value={@form_data[:slug]} required class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm font-mono" />
          </div>
        </div>

        <div>
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-semibold text-gray-900">Fields</h2>
            <button type="button" phx-click="add-field" class="inline-flex items-center rounded-md border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
              <svg class="-ml-1 mr-2 h-5 w-5 text-gray-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
              </svg>
              Add Field
            </button>
          </div>

          <div class="space-y-4">
            <%= for field <- @fields do %>
              <div class="relative bg-gray-50 p-6 rounded-lg border border-gray-200 shadow-sm">
                <!-- Close Button -->
                <div class="absolute top-4 right-4 text-gray-400 hover:text-red-500 cursor-pointer">
                  <button type="button" phx-click="remove-field" phx-value-id={field["id"]} title="Remove field" class="rounded hover:bg-red-50 p-1">
                    <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
                    </svg>
                  </button>
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 align-bottom pr-8">
                  <div class="col-span-1 lg:col-span-1 border-l-2 border-indigo-200 pl-4">
                    <label class="block text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1">Field Key <span class="text-red-500">*</span></label>
                    <input type="text" name={"fields[#{field["id"]}][key]"} value={field["key"]}
                           phx-blur="update-field" phx-value-id={field["id"]} phx-value-attr="key"
                           placeholder="e.g. title_image" required pattern="[a-zA-Z0-9_-]+"
                           class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm font-mono bg-white" />
                  </div>

                  <div class="col-span-1 lg:col-span-1">
                    <label class="block text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1">Label <span class="text-red-500">*</span></label>
                    <input type="text" name={"fields[#{field["id"]}][label]"} value={field["label"]}
                           phx-blur="update-field" phx-value-id={field["id"]} phx-value-attr="label"
                           placeholder="Title Image" required
                           class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm bg-white" />
                  </div>

                  <div class="col-span-1 lg:col-span-1">
                    <label class="block text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1">Type</label>
                    <select name={"fields[#{field["id"]}][field_type]"}
                            phx-change="update-field" phx-value-id={field["id"]} phx-value-attr="field_type"
                            class="block w-full px-3 py-2 border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md shadow-sm bg-white">
                      <%= Phoenix.HTML.Form.options_for_select(@field_types, field["field_type"]) %>
                    </select>
                  </div>

                  <div class="col-span-1 lg:col-span-1">
                    <%= if field["field_type"] in ["relation", "relation_many"] do %>
                      <label class="block text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1">Target <span class="text-red-500">*</span></label>
                      <select name={"fields[#{field["id"]}][target_model]"} required
                              phx-change="update-field" phx-value-id={field["id"]} phx-value-attr="target_model"
                              class="block w-full px-3 py-2 border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md shadow-sm bg-indigo-50">
                        <option value="">-- Model --</option>
                        <%= Phoenix.HTML.Form.options_for_select(
                              @available_models
                              |> Enum.reject(fn m -> @model && m.id == @model.id end)
                              |> Enum.map(&{&1.name, &1.slug}),
                              field["target_model"]
                            ) %>
                      </select>
                    <% end %>

                    <div class="mt-4 flex items-center">
                      <input type="checkbox" name={"fields[#{field["id"]}][required]"} checked={field["required"]} value="true"
                             phx-click="update-field" phx-value-id={field["id"]} phx-value-attr="required"
                             phx-value-value={to_string(!field["required"])} id={"req_#{field["id"]}"}
                             class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded cursor-pointer" />
                      <label for={"req_#{field["id"]}"} class="ml-2 block text-sm font-medium text-gray-700 cursor-pointer">
                        Required
                      </label>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if Enum.empty?(@fields) do %>
              <div class="text-center py-6 bg-white border-2 border-gray-300 border-dashed rounded-lg">
                <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6m-3-3v6m5 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                <h3 class="mt-2 text-sm font-medium text-gray-900">No fields</h3>
                <p class="mt-1 text-sm text-gray-500">Get started by adding a field to this model.</p>
              </div>
            <% end %>
          </div>
        </div>

        <div class="mt-8 pt-6 border-t border-gray-200 flex items-center space-x-4">
          <button type="submit" class="inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors">Save Model</button>
          <a href={"/admin/tenants/#{@current_tenant.slug}/models"} class="text-sm font-medium text-gray-600 hover:text-gray-900 transition-colors">Cancel</a>
        </div>
      </form>
    </div>
    """
  end

  defp schema_to_field_list(schema_def) do
    schema_def
    |> Enum.map(fn {key, attrs} ->
      Map.merge(attrs, %{"id" => Ecto.UUID.generate(), "key" => key})
    end)
  end

  defp validate_fields(fields, current_model_slug) do
    keys = Enum.map(fields, & &1["key"])

    duplicate_keys =
      keys
      |> Enum.frequencies()
      |> Enum.filter(fn {_, count} -> count > 1 end)
      |> Enum.map(&elem(&1, 0))

    Enum.reduce(fields, [], fn f, errors ->
      cond do
        String.trim(f["key"]) == "" ->
          ["Field key cannot be empty" | errors]

        not String.match?(f["key"], ~r/^[a-zA-Z0-9_-]+$/) ->
          ["Field key '#{f["key"]}' is invalid (only a-zA-Z0-9_- allowed)" | errors]

        f["key"] in duplicate_keys ->
          ["Field key '#{f["key"]}' is duplicated" | errors]

        String.trim(f["label"]) == "" ->
          ["Label cannot be empty for field '#{f["key"]}'" | errors]

        f["field_type"] in ["relation", "relation_many"] and
            String.trim(f["target_model"] || "") == "" ->
          ["Relation field '#{f["key"]}' requires a target model" | errors]

        f["field_type"] in ["relation", "relation_many"] and
          current_model_slug != nil and
            f["target_model"] == current_model_slug ->
          ["Relation field '#{f["key"]}' cannot reference the model itself" | errors]

        true ->
          errors
      end
    end)
    |> Enum.uniq()
  end
end
