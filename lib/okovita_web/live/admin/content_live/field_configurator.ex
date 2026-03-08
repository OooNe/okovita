defmodule OkovitaWeb.Admin.ContentLive.FieldConfigurator do
  @moduledoc """
  A base configurator component that renders the standard UI required for every field type
  (Field Key, Label, Type Selector, Required checkbox).

  Specific field types can then inject their custom configuration below this standard block
  via the `Registry.configurator_for/1` component.
  """
  use Phoenix.Component
  import OkovitaWeb.CoreComponents

  alias Okovita.FieldTypes.Registry

  @doc """
  Renders the standard field configuration UI plus any specific configurators.
  """
  def render(assigns) do
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
               placeholder="e.g. title" required pattern="[a-zA-Z0-9_-]+"
               class="font-mono" />

        <!-- Label -->
        <.input type="text" name={"fields[#{@field["id"]}][label]"} value={@field["label"]}
               label="Label" phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="label"
               placeholder="Title" required />

        <!-- Type -->
        <.input type="select" name={"fields[#{@field["id"]}][field_type]"} label="Type"
               value={@field["field_type"]} options={@field_types}
               phx-change="update-field" phx-value-id={@field["id"]} phx-value-attr="field_type" />

        <!-- Specific Type Config & Required Checkbox -->
        <div class="flex flex-col justify-between">
          <div>
            <%= if configurator = Registry.configurator_for(@field["field_type"]) do %>
              <%= configurator.render(%{field: @field, model: @model, available_models: @available_models}) %>
            <% end %>
          </div>

          <div class="mt-auto pt-2">
            <.input type="checkbox" name={"fields[#{@field["id"]}][required]"} checked={@field["required"]} label="Required"
                   id={"req_#{@field["id"]}"} phx-click="update-field" phx-value-id={@field["id"]} phx-value-attr="required"
                   phx-value-value={to_string(!@field["required"])} />
          </div>
        </div>
      </div>
    </div>
    """
  end
end
