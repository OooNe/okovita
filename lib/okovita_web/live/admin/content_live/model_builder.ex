defmodule OkovitaWeb.Admin.ContentLive.ModelBuilder do
  @moduledoc "Tenant admin: create and edit content models with dynamic field definitions."
  use OkovitaWeb, :live_view

  alias Okovita.Content
  alias Okovita.FieldTypes.Registry

  @persisted_field_keys ~w(label field_type required target_model position
                           validation_regex min_length max_length min max)

  def mount(%{"id" => id}, _session, socket) do
    prefix = socket.assigns.tenant_prefix
    model = Content.get_model(id, prefix)
    available_models = Content.list_models(prefix)

    if model do
      fields =
        model.schema_definition
        |> schema_to_field_list()
        |> sort_fields()

      {:ok,
       assign(socket,
         model: model,
         form_data: %{slug: model.slug, name: model.name, slug_field: model.slug_field, publishable: model.publishable},
         fields: fields,
         field_types: Registry.registered_types(),
         available_models: available_models,
         prefix: prefix,
         show_json_modal: false,
         json_definition: "",
         regex_test_results: %{},
         validation_open: MapSet.new()
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
       form_data: %{slug: "", name: "", slug_field: nil, publishable: false},
       fields: [],
       field_types: Registry.registered_types(),
       available_models: available_models,
       prefix: prefix,
       show_json_modal: false,
       json_definition: "",
       regex_test_results: %{},
       validation_open: MapSet.new()
     )}
  end

  def handle_event("add-field", _params, socket) do
    new_field = %{
      "id" => Ecto.UUID.generate(),
      "key" => "",
      "field_type" => "text",
      "label" => "",
      "required" => false,
      "position" => length(socket.assigns.fields)
    }

    fields = socket.assigns.fields ++ [new_field]
    {:noreply, assign(socket, fields: fields)}
  end

  def handle_event("remove-field", %{"id" => id}, socket) do
    fields = Enum.reject(socket.assigns.fields, &(&1["id"] == id))
    {:noreply, assign(socket, fields: fields)}
  end

  def handle_event("update-form", %{"fields_order" => order}, socket) do
    # Sortable hook sends the list of IDs in the new order
    fields =
      order
      |> Enum.with_index()
      |> Enum.reduce(socket.assigns.fields, fn {id, index}, acc ->
        Enum.map(acc, fn
          %{"id" => ^id} = f -> Map.put(f, "position", index)
          f -> f
        end)
      end)
      |> sort_fields()

    {:noreply, assign(socket, fields: fields)}
  end

  def handle_event("update-form", params, socket) do
    form_data = %{
      slug: params["slug"],
      name: params["name"],
      slug_field: if(params["slug_field"] in ["", nil], do: nil, else: params["slug_field"]),
      publishable: params["publishable"] == "true"
    }

    {:noreply, assign(socket, form_data: form_data)}
  end

  def handle_event("show-json", _params, socket) do
    fields = socket.assigns.fields
    form_data = socket.assigns.form_data

    schema_definition =
      Enum.reduce(fields, %{}, fn f, acc ->
        field_data = f |> Map.take(@persisted_field_keys) |> reject_blank_values()
        Map.put(acc, f["key"], field_data)
      end)

    attrs = %{
      slug: form_data[:slug],
      name: form_data[:name],
      slug_field: form_data[:slug_field],
      publishable: form_data[:publishable],
      schema_definition: schema_definition
    }

    json = Jason.encode!(attrs, pretty: true)
    {:noreply, assign(socket, show_json_modal: true, json_definition: json)}
  end

  def handle_event("close-json", _params, socket) do
    {:noreply, assign(socket, show_json_modal: false)}
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

  def handle_event("toggle-validation", %{"id" => id}, socket) do
    open = socket.assigns.validation_open

    open =
      if MapSet.member?(open, id),
        do: MapSet.delete(open, id),
        else: MapSet.put(open, id)

    {:noreply, assign(socket, validation_open: open)}
  end


  def handle_event("save", params, socket) do
    prefix = socket.assigns.prefix
    fields = socket.assigns.fields

    current_model_slug = if socket.assigns.model, do: socket.assigns.model.slug, else: nil
    errors_list = validate_fields(fields, current_model_slug)

    if Enum.empty?(errors_list) do
      schema_definition =
        Enum.reduce(fields, %{}, fn f, acc ->
          field_data = f |> Map.take(@persisted_field_keys) |> reject_blank_values()
          Map.put(acc, f["key"], field_data)
        end)

      attrs = %{
        slug: params["slug"],
        name: params["name"],
        slug_field: if(params["slug_field"] in ["", nil], do: nil, else: params["slug_field"]),
        publishable: params["publishable"] == "true",
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

  @integer_attrs ~w(min_length max_length)
  @number_attrs ~w(min max)

  defp update_field_in_socket(socket, id, attr, value) do
    value = cast_field_attr(attr, value)

    fields =
      Enum.map(socket.assigns.fields, fn
        %{"id" => ^id} = f -> Map.put(f, attr, value)
        f -> f
      end)

    {:noreply, assign(socket, fields: fields)}
  end

  defp cast_field_attr("required", val), do: val == "true"

  defp cast_field_attr(attr, val) when attr in @integer_attrs do
    case Integer.parse(to_string(val)) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp cast_field_attr(attr, val) when attr in @number_attrs do
    str = to_string(val)

    cond do
      str == "" -> nil
      true ->
        case Float.parse(str) do
          {n, _} -> n
          :error -> nil
        end
    end
  end

  defp cast_field_attr(_attr, val), do: val

  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={:admin}>
    <div class="max-w-4xl mx-auto bg-white rounded-xl shadow-sm ring-1 ring-gray-900/5 p-8 my-8">
      <div class="border-b border-gray-200 pb-5 mb-8 flex items-center justify-between">
        <h1 class="text-2xl font-bold leading-tight text-gray-900">
          <%= if @model, do: "Edit Model", else: "New Model" %>
        </h1>
        <div class="flex items-center gap-6">
          <div class="flex items-center gap-1.5">
            <label class="relative inline-flex items-center cursor-pointer">
              <input type="hidden" name="publishable" value="false" form="model-form" />
              <input type="checkbox" name="publishable" value="true" checked={@form_data[:publishable]} class="sr-only peer" form="model-form" />
              <div class="w-9 h-5 bg-gray-200 peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-indigo-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-indigo-600"></div>
              <span class="ml-2 text-sm font-medium text-gray-700">Publishable</span>
            </label>
            <div class="relative group">
              <div class="flex items-center justify-center w-4 h-4 rounded-full bg-gray-400 cursor-help select-none">
                <span class="text-white text-[10px] font-bold leading-none">i</span>
              </div>
            <div class="absolute right-0 top-full mt-2 w-64 rounded-lg bg-gray-900 px-3 py-2 text-xs text-white shadow-lg opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all z-50">
              Entries require explicit publishing to be visible via API.
              <div class="absolute -top-1 right-2 w-2 h-2 rotate-45 bg-gray-900"></div>
            </div>
            </div>
          </div>
          <a href={"/admin/tenants/#{@current_tenant.slug}/models"} class="text-sm font-medium text-gray-600 hover:text-gray-900 transition-colors">
            Back to models
          </a>
        </div>
      </div>

      <form phx-change="update-form" phx-submit="save" id="model-form" class="space-y-8">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 pb-8 border-b border-gray-200">
          <.input type="text" name="name" label="Name" value={@form_data[:name]} required placeholder="e.g. BlogPost" />
          <.input type="text" name="slug" label="Slug" value={@form_data[:slug]} required placeholder="e.g. blog_post" />
          
          <div>
            <.input type="select" name="slug_field" label="Slug generated from field" value={@form_data[:slug_field]} prompt="- Manual entry -"
              options={Enum.map(@fields, fn f -> {if(f["label"] == "", do: f["key"], else: f["label"]) <> " (" <> f["key"] <> ")", f["key"]} end) |> Enum.filter(fn {_, k} -> Enum.find(@fields, &(&1["key"] == k))["field_type"] == "text" end)} />
            <p class="mt-1 text-sm text-gray-500">Select a text field to automatically generate slug from it.</p>
          </div>
        </div>

        <div>
          <div class="flex justify-between items-center mb-6">
            <div>
            <h2 class="text-xl font-semibold text-gray-900">Fields</h2>
            <p class="text-sm text-gray-500 mt-1">Define the available fields for this model and their order.</p>
          </div>
          <div class="flex items-center gap-3">
            <.button type="button" phx-click="show-json" phx-target="#model-form" variant="secondary">
              <.icon name="hero-information-circle" class="w-4 h-4 mr-2" />
              View JSON
            </.button>
            <.button type="button" phx-click="add-field" variant="secondary">
              <.icon name="hero-plus" class="w-4 h-4 mr-2" />
              Add Field
            </.button>
          </div>
        </div>

          <div class="space-y-4" phx-hook="Sortable" id="fields-list">
            <%= for field <- @fields do %>
              <div id={field["id"]} class="group">
                <input type="hidden" name="fields_order[]" value={field["id"]} />
                <OkovitaWeb.Admin.ContentLive.FieldConfigurator.render field={field} field_types={@field_types} available_models={@available_models} model={@model} validation_open?={MapSet.member?(@validation_open, field["id"])} />
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

        <div class="mt-8 pt-6 border-t border-gray-200 flex items-center justify-end space-x-4">
          <a href={"/admin/tenants/#{@current_tenant.slug}/models"} class="text-sm font-medium text-gray-600 hover:text-gray-900 transition-colors">Cancel</a>
          <.button type="submit">Save Model</.button>
        </div>
      </form>
    </div>

    <.modal id="json-modal" show={@show_json_modal} on_close="close-json">
      <:title>Model Definition JSON</:title>
      <div class="mt-4">
        <div class="flex justify-between items-center mb-2">
          <p class="text-sm text-gray-500">Copy this JSON to use in other environments or for backup.</p>
          <button type="button" onclick={"navigator.clipboard.writeText(#{inspect(@json_definition)})"} class="text-xs font-medium text-indigo-600 hover:text-indigo-800 flex items-center gap-1">
            <.icon name="hero-check" class="w-4 h-4" />
            Copy to clipboard
          </button>
        </div>
        <pre class="p-4 bg-gray-900 text-gray-100 rounded-lg overflow-x-auto text-sm max-h-[60vh] font-sans"><%= @json_definition %></pre>
      </div>
      <:footer>
        <.button type="button" phx-click="close-json" variant="secondary">Close</.button>
      </:footer>
    </.modal>
    </Layouts.app>
    """
  end

  defp schema_to_field_list(schema_def) do
    schema_def
    |> Enum.map(fn {key, attrs} ->
      Map.merge(attrs, %{"id" => Ecto.UUID.generate(), "key" => key})
      |> Map.put_new("position", 0)
    end)
  end

  defp sort_fields(fields) do
    Enum.sort_by(fields, & &1["position"])
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

        Registry.targets_entry?(f["field_type"]) and
            String.trim(f["target_model"] || "") == "" ->
          ["Relation field '#{f["key"]}' requires a target model" | errors]

        Registry.targets_entry?(f["field_type"]) and
          current_model_slug != nil and
            f["target_model"] == current_model_slug ->
          ["Relation field '#{f["key"]}' cannot reference the model itself" | errors]

        true ->
          errors
      end
    end)
    |> check_regex_patterns(fields)
    |> Enum.uniq()
  end

  defp check_regex_patterns(errors, fields) do
    Enum.reduce(fields, errors, fn f, acc ->
      case f["validation_regex"] do
        nil -> acc
        "" -> acc

        pattern when is_binary(pattern) ->
          case Regex.compile(pattern) do
            {:ok, _} -> acc
            {:error, _} -> ["Invalid regex pattern for field '#{f["key"]}': #{pattern}" | acc]
          end

        _ -> acc
      end
    end)
  end

  defp reject_blank_values(map) do
    Map.reject(map, fn
      {_, nil} -> true
      {_, ""} -> true
      _ -> false
    end)
  end
end
