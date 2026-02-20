defmodule OkovitaWeb.Admin.ContentLive.EntryForm do
  @moduledoc "Tenant admin: create or edit a content entry with dynamic form from schema_definition."
  use OkovitaWeb, :live_view

  alias Okovita.Content

  on_mount {OkovitaWeb.LiveAuth, :require_tenant_admin}

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
    <div style="max-width: 900px; margin: 40px auto; padding: 20px; background: white; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
      <h1 style="font-size: 24px; font-weight: bold; margin-bottom: 24px; color: #111827;">
        <%= if @entry, do: "Edit Entry", else: "New Entry" %> — <%= @model.name %>
      </h1>

      <form phx-submit="save" style="display: flex; flex-direction: column; gap: 24px;">
        <div>
          <label style="display: block; font-weight: 600; margin-bottom: 8px; color: #374151;">Slug</label>
          <input type="text" name="slug" value={@slug} required style="width: 100%; padding: 8px 12px; border: 1px solid #D1D5DB; border-radius: 4px; box-sizing: border-box;" />
        </div>

        <%= for {field_name, field_def} <- @model.schema_definition do %>
          <div>
            <label for={field_name} style="display: block; font-weight: 600; margin-bottom: 8px; color: #374151;">
              <%= field_def["label"] %>
              <span :if={field_def["required"]} style="color: #EF4444;">*</span>
            </label>
            <%= render_field_input(field_name, field_def, @data, @relation_options) %>

            <%= for err <- (@errors[String.to_atom(field_name)] || []) do %>
              <p style="color: #EF4444; font-size: 14px; margin-top: 4px;"><%= err %></p>
            <% end %>
          </div>
        <% end %>

        <div style="margin-top: 32px; padding-top: 24px; border-top: 1px solid #E5E7EB; display: flex; align-items: center; gap: 16px;">
          <button type="submit" style="padding: 10px 24px; background: #4F46E5; color: white; border: none; border-radius: 6px; font-weight: 500; cursor: pointer;">Save Entry</button>
          <a href={"/admin/tenants/#{@current_tenant.slug}/models/#{@model.slug}/entries"} style="color: #6B7280; text-decoration: none; font-weight: 500;">Cancel</a>
        </div>
      </form>
    </div>
    """
  end

  defp render_field_input(name, %{"field_type" => "textarea"}, data, _relation_options) do
    assigns = %{name: name, value: Map.get(data, name, "")}

    ~H"""
    <textarea name={@name} rows="5" style="width: 100%; padding: 8px 12px; border: 1px solid #D1D5DB; border-radius: 4px; box-sizing: border-box; font-family: inherit;"><%= @value %></textarea>
    """
  end

  defp render_field_input(name, %{"field_type" => "boolean"}, data, _relation_options) do
    assigns = %{name: name, checked: Map.get(data, name) in [true, "true"]}

    ~H"""
    <input type="checkbox" name={@name} value="true" checked={@checked} style="width: 16px; height: 16px; accent-color: #4F46E5; cursor: pointer;" />
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
    <select name={@name} style="width: 100%; padding: 8px 12px; border: 1px solid #D1D5DB; border-radius: 4px; box-sizing: border-box; background-color: white;">
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
    <select name={@name} style="width: 100%; padding: 8px 12px; border: 1px solid #D1D5DB; border-radius: 4px; box-sizing: border-box; background-color: white;">
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
    <input type={@type} step={@step} name={@name} value={@value} style="width: 100%; padding: 8px 12px; border: 1px solid #D1D5DB; border-radius: 4px; box-sizing: border-box;" />
    """
  end

  defp render_field_input(name, %{"field_type" => "date"}, data, _relation_options) do
    assigns = %{name: name, value: Map.get(data, name, "")}

    ~H"""
    <input type="date" name={@name} value={@value} style="width: 100%; padding: 8px 12px; border: 1px solid #D1D5DB; border-radius: 4px; box-sizing: border-box;" />
    """
  end

  defp render_field_input(name, %{"field_type" => "datetime"}, data, _relation_options) do
    assigns = %{name: name, value: Map.get(data, name, "")}

    ~H"""
    <input type="datetime-local" name={@name} value={@value} style="width: 100%; padding: 8px 12px; border: 1px solid #D1D5DB; border-radius: 4px; box-sizing: border-box;" />
    """
  end

  defp render_field_input(name, _field_def, data, _relation_options) do
    assigns = %{name: name, value: Map.get(data, name, "")}

    ~H"""
    <input type="text" name={@name} value={@value} style="width: 100%; padding: 8px 12px; border: 1px solid #D1D5DB; border-radius: 4px; box-sizing: border-box;" />
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
