defmodule OkovitaWeb.Admin.ContentLive.ModelBuilder do
  @moduledoc "Tenant admin: create and edit content models with dynamic field definitions."
  use OkovitaWeb, :live_view

  alias Okovita.Content
  alias Okovita.FieldTypes.Registry

  on_mount {OkovitaWeb.LiveAuth, :require_tenant_admin}

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

    errors_list = validate_fields(fields)

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
    <div style="max-width: 1000px; margin: 40px auto; padding: 20px; background: white; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
      <h1 style="font-size: 24px; font-weight: bold; margin-bottom: 24px; color: #111827;">
        <%= if @model, do: "Edit Model", else: "New Model" %>
      </h1>

      <form phx-change="update-form" phx-submit="save" id="model-form" style="display: flex; flex-direction: column;">
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 32px;">
          <div>
            <label style="display: block; font-weight: 600; margin-bottom: 8px; color: #374151;">Name <span style="color: #EF4444;">*</span></label>
            <input type="text" name="name" value={@form_data[:name]} required style="width: 100%; padding: 8px 12px; border: 1px solid #D1D5DB; border-radius: 4px; box-sizing: border-box;" />
          </div>
          <div>
            <label style="display: block; font-weight: 600; margin-bottom: 8px; color: #374151;">Slug <span style="color: #EF4444;">*</span></label>
            <input type="text" name="slug" value={@form_data[:slug]} required style="width: 100%; padding: 8px 12px; border: 1px solid #D1D5DB; border-radius: 4px; box-sizing: border-box;" />
          </div>
        </div>

        <h2 style="font-size: 20px; font-weight: 600; margin-bottom: 16px; color: #1F2937;">Fields</h2>

        <%= for field <- @fields do %>
          <div style="border: 1px solid #E5E7EB; padding: 16px; border-radius: 8px; margin-bottom: 12px; background: #F9FAFB;">
            <div style="display: grid; grid-template-columns: 1.5fr 1.5fr 1fr 1fr auto auto; gap: 12px; align-items: flex-end;">

              <div>
                <label style="display: block; font-size: 14px; font-weight: 500; margin-bottom: 4px; color: #4B5563;">Field Key <span style="color: #EF4444;">*</span></label>
                <input type="text" name={"fields[#{field["id"]}][key]"} value={field["key"]}
                       phx-blur="update-field" phx-value-id={field["id"]} phx-value-attr="key"
                       placeholder="e.g. title_image" required pattern="[a-zA-Z0-9_-]+"
                       style="width: 100%; padding: 6px 10px; border: 1px solid #D1D5DB; border-radius: 4px; box-sizing: border-box; font-family: monospace; font-size: 14px;" />
              </div>

              <div>
                <label style="display: block; font-size: 14px; font-weight: 500; margin-bottom: 4px; color: #4B5563;">Label <span style="color: #EF4444;">*</span></label>
                <input type="text" name={"fields[#{field["id"]}][label]"} value={field["label"]}
                       phx-blur="update-field" phx-value-id={field["id"]} phx-value-attr="label"
                       placeholder="Title Image" required
                       style="width: 100%; padding: 6px 10px; border: 1px solid #D1D5DB; border-radius: 4px; box-sizing: border-box; font-size: 14px;" />
              </div>

              <div>
                <label style="display: block; font-size: 14px; font-weight: 500; margin-bottom: 4px; color: #4B5563;">Type</label>
                <select name={"fields[#{field["id"]}][field_type]"}
                        phx-change="update-field" phx-value-id={field["id"]} phx-value-attr="field_type"
                        style="width: 100%; padding: 6px 10px; border: 1px solid #D1D5DB; border-radius: 4px; box-sizing: border-box; font-size: 14px; background: white;">
                  <%= Phoenix.HTML.Form.options_for_select(@field_types, field["field_type"]) %>
                </select>
              </div>

              <div style="width: 100%;">
                <%= if field["field_type"] == "relation" do %>
                  <label style="display: block; font-size: 14px; font-weight: 500; margin-bottom: 4px; color: #4B5563;">Target <span style="color: #EF4444;">*</span></label>
                  <select name={"fields[#{field["id"]}][target_model]"} required
                          phx-change="update-field" phx-value-id={field["id"]} phx-value-attr="target_model"
                          style="width: 100%; padding: 6px 10px; border: 1px solid #D1D5DB; border-radius: 4px; box-sizing: border-box; font-size: 14px; background: white;">
                    <option value="">-- Model --</option>
                    <%= Phoenix.HTML.Form.options_for_select(Enum.map(@available_models, &{&1.name, &1.slug}), field["target_model"]) %>
                  </select>
                <% end %>
              </div>

              <div style="padding-bottom: 8px; display: flex; align-items: center; gap: 6px;">
                <input type="checkbox" name={"fields[#{field["id"]}][required]"} checked={field["required"]} value="true"
                       phx-click="update-field" phx-value-id={field["id"]} phx-value-attr="required"
                       phx-value-value={to_string(!field["required"])} id={"req_#{field["id"]}"}
                       style="width: 16px; height: 16px; accent-color: #4F46E5; cursor: pointer;" />
                <label for={"req_#{field["id"]}"} style="font-size: 14px; font-weight: 500; color: #4B5563; cursor: pointer;">Required</label>
              </div>

              <div style="padding-bottom: 4px;">
                <button type="button" phx-click="remove-field" phx-value-id={field["id"]} title="Remove field"
                        style="padding: 6px 12px; background: #FEF2F2; color: #DC2626; border: 1px solid #FCA5A5; border-radius: 4px; cursor: pointer; font-size: 14px; font-weight: bold;">
                  ✕
                </button>
              </div>

            </div>
          </div>
        <% end %>

        <div style="margin-bottom: 24px; margin-top: 8px;">
          <button type="button" phx-click="add-field" style="padding: 8px 16px; background: #F3F4F6; color: #374151; border: 1px solid #D1D5DB; border-radius: 6px; cursor: pointer; font-weight: 500;">
            + Add Field
          </button>
        </div>

        <div style="margin-top: 24px; padding-top: 24px; border-top: 1px solid #E5E7EB; display: flex; align-items: center; gap: 16px;">
          <button type="submit" style="padding: 10px 24px; background: #4F46E5; color: white; border: none; border-radius: 6px; font-weight: 500; cursor: pointer;">Save Model</button>
          <a href={"/admin/tenants/#{@current_tenant.slug}/models"} style="color: #6B7280; text-decoration: none; font-weight: 500;">Cancel</a>
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

  defp validate_fields(fields) do
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

        f["field_type"] == "relation" and String.trim(f["target_model"] || "") == "" ->
          ["Relation field '#{f["key"]}' requires a target model" | errors]

        true ->
          errors
      end
    end)
    |> Enum.uniq()
  end
end
