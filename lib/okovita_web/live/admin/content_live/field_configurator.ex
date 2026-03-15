defmodule OkovitaWeb.Admin.ContentLive.FieldConfigurator do
  @moduledoc """
  A base configurator component that renders the standard UI required for every field type
  (Field Key, Label, Type Selector) plus a collapsible validation panel.

  Specific field types can inject their custom configuration via `Registry.configurator_for/1`.
  Validation options are rendered conditionally based on `field_type`.
  """
  use Phoenix.Component
  import OkovitaWeb.CoreComponents

  alias Okovita.FieldTypes.Registry

  @text_types ~w(text textarea)
  @regex_types ~w(text textarea url)
  @numeric_types ~w(integer number)
  @date_types ~w(date datetime)
  @list_types ~w(list)

  @doc """
  Renders the standard field configuration UI plus any specific configurators
  and the collapsible validation panel.
  """
  def render(assigns) do
    ft = assigns.field["field_type"]

    assigns =
      assigns
      |> assign_new(:validation_open?, fn -> false end)
      |> assign(:is_text_type, ft in @text_types)
      |> assign(:is_regex_type, ft in @regex_types)
      |> assign(:is_numeric_type, ft in @numeric_types)
      |> assign(:is_date_type, ft in @date_types)
      |> assign(:is_list_type, ft in @list_types)
      |> assign(:has_rules?, has_rules?(assigns.field, assigns.model))

    ~H"""
    <div class="relative bg-white p-6 rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition-shadow group/card">
      <!-- Drag Handle -->
      <div class="absolute top-4 left-4 text-gray-300 cursor-move group-hover/card:text-indigo-400 transition-colors">
        <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
          <path fill-rule="evenodd" d="M10 3a1.5 1.5 0 110 3 1.5 1.5 0 010-3zM10 8.5a1.5 1.5 0 110 3 1.5 1.5 0 010-3zM10 14a1.5 1.5 0 110 3 1.5 1.5 0 010-3z" clip-rule="evenodd" />
        </svg>
      </div>

      <!-- Remove Button -->
      <div class="absolute top-4 right-4 text-gray-400 opacity-0 group-hover/card:opacity-100 transition-opacity">
        <button type="button" phx-click="remove-field" phx-value-id={@field["id"]} title="Remove field" class="rounded hover:bg-red-50 hover:text-red-500 p-1 transition-colors">
          <.icon name="hero-x-mark" class="w-5 h-5" />
        </button>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-x-6 gap-y-4 pr-6 pl-6">
        <!-- Field Key -->
        <.input type="text" name={"fields[#{@field["id"]}][key]"} value={@field["key"]}
               label="Field Key" phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="key"
               placeholder="e.g. title" required pattern="[a-zA-Z0-9_-]+" />

        <!-- Label -->
        <.input type="text" name={"fields[#{@field["id"]}][label]"} value={@field["label"]}
               label="Label" phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="label"
               placeholder="Title" required />

        <!-- Type -->
        <.input type="select" name={"fields[#{@field["id"]}][field_type]"} label="Type"
               value={@field["field_type"]} options={@field_types}
               phx-change="update-field" phx-value-id={@field["id"]} phx-value-attr="field_type" />

        <!-- Specific Type Config -->
        <div>
          <%= if configurator = Registry.configurator_for(@field["field_type"]) do %>
            <%= configurator.render(%{field: @field, model: @model, available_models: @available_models}) %>
          <% end %>
        </div>
      </div>

      <!-- Collapsible Validation Panel -->
      <div class="mt-4 px-6">
        <button type="button" phx-click="toggle-validation" phx-value-id={@field["id"]}
                class="cursor-pointer text-sm font-medium text-indigo-600 hover:text-indigo-800 transition-colors select-none flex items-center gap-1.5 py-2">
          <.icon name={if @validation_open?, do: "hero-chevron-down", else: "hero-chevron-right"} class="w-4 h-4" />
          <%= if @has_rules?, do: "Modify validation rules", else: "Add validation rules" %>
        </button>

        <div :if={@validation_open?} class="mt-3 pt-4 border-t border-gray-100 space-y-4">
          <!-- Required -->
          <.input type="checkbox" name={"fields[#{@field["id"]}][required]"} checked={@field["required"]} label="Required"
                 id={"req_#{@field["id"]}"} phx-click="update-field" phx-value-id={@field["id"]} phx-value-attr="required"
                 phx-value-value={to_string(!@field["required"])} />

          <!-- Min/Max Length: text, textarea -->
          <%= if @is_text_type do %>
            <div class="grid grid-cols-2 gap-4">
              <.input type="number" name={"fields[#{@field["id"]}][min_length]"}
                     value={@field["min_length"]} label="Min length"
                     phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="min_length"
                     placeholder="e.g. 3" min="0" />
              <.input type="number" name={"fields[#{@field["id"]}][max_length]"}
                     value={@field["max_length"]} label="Max length"
                     phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="max_length"
                     placeholder="e.g. 200" min="0" />
            </div>
          <% end %>

          <!-- Min/Max Range: integer, number -->
          <%= if @is_numeric_type do %>
            <div class="grid grid-cols-2 gap-4">
              <.input type="number" name={"fields[#{@field["id"]}][min]"}
                     value={@field["min"]} label="Min value"
                     phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="min"
                     placeholder="e.g. 0" step={if(@field["field_type"] == "number", do: "any", else: "1")} />
              <.input type="number" name={"fields[#{@field["id"]}][max]"}
                     value={@field["max"]} label="Max value"
                     phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="max"
                     placeholder="e.g. 1000" step={if(@field["field_type"] == "number", do: "any", else: "1")} />
            </div>
          <% end %>

          <!-- Min/Max Date: date, datetime -->
          <%= if @is_date_type do %>
            <div class="grid grid-cols-2 gap-4">
              <.input type={if(@field["field_type"] == "datetime", do: "datetime-local", else: "date")}
                     name={"fields[#{@field["id"]}][min]"}
                     value={@field["min"]} label="Earliest date"
                     phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="min" />
              <.input type={if(@field["field_type"] == "datetime", do: "datetime-local", else: "date")}
                     name={"fields[#{@field["id"]}][max]"}
                     value={@field["max"]} label="Latest date"
                     phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="max" />
            </div>
          <% end %>

          <!-- Regex: text, textarea, url -->
          <%= if @is_regex_type do %>
            <.input type="text" name={"fields[#{@field["id"]}][validation_regex]"}
                   value={@field["validation_regex"]} label="Validation regex"
                   phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="validation_regex"
                   placeholder="e.g. ^[A-Z]{2}-\\d{4}$" />
          <% end %>

          <!-- Min/Max Items + per-item validation: list -->
          <%= if @is_list_type do %>
            <div class="grid grid-cols-2 gap-4">
              <.input type="number" name={"fields[#{@field["id"]}][min_items]"}
                     value={@field["min_items"]} label="Min items"
                     phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="min_items"
                     placeholder="e.g. 1" min="0" />
              <.input type="number" name={"fields[#{@field["id"]}][max_items]"}
                     value={@field["max_items"]} label="Max items"
                     phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="max_items"
                     placeholder="e.g. 10" min="0" />
            </div>
            <div class="grid grid-cols-2 gap-4">
              <.input type="number" name={"fields[#{@field["id"]}][min_length]"}
                     value={@field["min_length"]} label="Min item length"
                     phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="min_length"
                     placeholder="e.g. 2" min="0" />
              <.input type="number" name={"fields[#{@field["id"]}][max_length]"}
                     value={@field["max_length"]} label="Max item length"
                     phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="max_length"
                     placeholder="e.g. 100" min="0" />
            </div>
            <.input type="text" name={"fields[#{@field["id"]}][validation_regex]"}
                   value={@field["validation_regex"]} label="Item validation regex"
                   phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="validation_regex"
                   placeholder="e.g. ^[A-Z]{2}-\\d{4}$" />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @validation_keys ~w(required validation_regex min_length max_length min max min_items max_items)
  defp has_rules?(_field, nil), do: false

  defp has_rules?(field, model) do
    key = field["key"]
    persisted = get_in(model.schema_definition, [key]) || %{}

    Enum.any?(@validation_keys, fn k ->
      val = persisted[k]
      val != nil and val != "" and val != false
    end)
  end
end
