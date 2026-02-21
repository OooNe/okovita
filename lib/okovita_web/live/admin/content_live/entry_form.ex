defmodule OkovitaWeb.Admin.ContentLive.EntryForm do
  @moduledoc "Tenant admin: create or edit a content entry with dynamic form from schema_definition."
  use OkovitaWeb, :live_view

  alias Okovita.Content

  def mount(%{"model_slug" => slug, "id" => id}, _session, socket) do
    prefix = socket.assigns.tenant_prefix
    model = Content.get_model_by_slug(slug, prefix)
    entry = if model, do: Content.get_entry(id, prefix)

    if model && entry do
      {:ok,
       assign(socket,
         model: model,
         entry: entry,
         data: entry.data,
         slug: entry.slug,
         prefix: prefix,
         errors: %{},
         relation_options: load_relation_options(model, prefix)
       )}
    else
      {:ok, push_navigate(socket, to: "/admin/models")}
    end
  end

  def mount(%{"model_slug" => slug}, _session, socket) do
    prefix = socket.assigns.tenant_prefix
    model = Content.get_model_by_slug(slug, prefix)

    if model do
      {:ok,
       assign(socket,
         model: model,
         entry: nil,
         data: %{},
         slug: "",
         prefix: prefix,
         errors: %{},
         relation_options: load_relation_options(model, prefix)
       )}
    else
      {:ok, push_navigate(socket, to: "/admin/models")}
    end
  end

  def handle_event("save", params, socket) do
    prefix = socket.assigns.prefix
    model = socket.assigns.model
    slug = params["slug"] || ""

    # Collect field values from params
    data =
      model.schema_definition
      |> Enum.into(%{}, fn {field_name, _def} ->
        {field_name, Map.get(params, field_name, "")}
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

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto bg-white rounded-xl shadow-sm ring-1 ring-gray-900/5 p-8">
      <h1 class="text-2xl font-bold text-gray-900 mb-8">
        <%= if @entry, do: "Edit Entry", else: "New Entry" %> — <span class="text-indigo-600"><%= @model.name %></span>
      </h1>

      <form phx-submit="save" class="space-y-6">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Slug</label>
          <input type="text" name="slug" value={@slug} required class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
        </div>

        <%= for {field_name, field_def} <- @model.schema_definition do %>
          <div>
            <label for={field_name} class="block text-sm font-medium text-gray-700 mb-1">
              <%= field_def["label"] %>
              <span :if={field_def["required"]} class="text-red-500">*</span>
            </label>
            <%= render_field_input(field_name, field_def, @data, @relation_options) %>

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

  defp render_field_input(name, %{"field_type" => "textarea"}, data, _relation_options) do
    assigns = %{name: name, value: Map.get(data, name, "")}

    ~H"""
    <textarea name={@name} rows="5" class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm font-sans"><%= @value %></textarea>
    """
  end

  defp render_field_input(name, %{"field_type" => "boolean"}, data, _relation_options) do
    assigns = %{name: name, checked: Map.get(data, name) in [true, "true"]}

    ~H"""
    <input type="checkbox" name={@name} value="true" checked={@checked} class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded cursor-pointer" />
    """
  end

  defp render_field_input(
         name,
         %{"field_type" => "enum", "one_of" => options},
         data,
         _relation_options
       ) do
    assigns = %{name: name, value: Map.get(data, name, ""), options: options}

    ~H"""
    <select name={@name} class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md bg-white">
      <option value="">Select...</option>
      <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
    </select>
    """
  end

  defp render_field_input(name, %{"field_type" => "relation"}, data, relation_options) do
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

  defp render_field_input(name, %{"field_type" => type}, data, _relation_options)
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

  defp render_field_input(name, %{"field_type" => "date"}, data, _relation_options) do
    assigns = %{name: name, value: Map.get(data, name, "")}

    ~H"""
    <input type="date" name={@name} value={@value} class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
    """
  end

  defp render_field_input(name, %{"field_type" => "datetime"}, data, _relation_options) do
    assigns = %{name: name, value: Map.get(data, name, "")}

    ~H"""
    <input type="datetime-local" name={@name} value={@value} class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
    """
  end

  defp render_field_input(name, _field_def, data, _relation_options) do
    assigns = %{name: name, value: Map.get(data, name, "")}

    ~H"""
    <input type="text" name={@name} value={@value} class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
    """
  end

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
