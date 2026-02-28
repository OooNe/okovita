defmodule OkovitaWeb.Admin.ContentLive.FieldConfigurator do
  @moduledoc """
  A base configurator component that renders the standard UI required for every field type
  (Field Key, Label, Type Selector, Required checkbox).

  Specific field types can then inject their custom configuration below this standard block
  via the `Registry.configurator_for/1` component.
  """
  use Phoenix.Component

  alias Okovita.FieldTypes.Registry

  @doc """
  Renders the standard field configuration UI plus any specific configurators.
  """
  def render(assigns) do
    ~H"""
    <div class="relative bg-gray-50 p-6 rounded-lg border border-gray-200 shadow-sm">
      <!-- Close Button -->
      <div class="absolute top-4 right-4 text-gray-400 hover:text-red-500 cursor-pointer">
        <button type="button" phx-click="remove-field" phx-value-id={@field["id"]} title="Remove field" class="rounded hover:bg-red-50 p-1">
          <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
            <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
          </svg>
        </button>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 align-bottom pr-8">
        <!-- Field Key -->
        <div class="col-span-1 lg:col-span-1 border-l-2 border-indigo-200 pl-4">
          <label class="block text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1">Field Key <span class="text-red-500">*</span></label>
          <input type="text" name={"fields[#{@field["id"]}][key]"} value={@field["key"]}
                 phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="key"
                 placeholder="e.g. title_image" required pattern="[a-zA-Z0-9_-]+"
                 class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm font-mono bg-white" />
        </div>

        <!-- Label -->
        <div class="col-span-1 lg:col-span-1">
          <label class="block text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1">Label <span class="text-red-500">*</span></label>
          <input type="text" name={"fields[#{@field["id"]}][label]"} value={@field["label"]}
                 phx-blur="update-field" phx-value-id={@field["id"]} phx-value-attr="label"
                 placeholder="Title Image" required
                 class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm bg-white" />
        </div>

        <!-- Type -->
        <div class="col-span-1 lg:col-span-1">
          <label class="block text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1">Type</label>
          <select name={"fields[#{@field["id"]}][field_type]"}
                  phx-change="update-field" phx-value-id={@field["id"]} phx-value-attr="field_type"
                  class="block w-full px-3 py-2 border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md shadow-sm bg-white">
            <%= Phoenix.HTML.Form.options_for_select(@field_types, @field["field_type"]) %>
          </select>
        </div>

        <!-- Specific Type Config & Required Checkbox -->
        <div class="col-span-1 lg:col-span-1">
          <%= if configurator = Registry.configurator_for(@field["field_type"]) do %>
            <div class="mb-4">
              <%= configurator.render(%{field: @field, model: @model, available_models: @available_models}) %>
            </div>
          <% end %>

          <div class="mt-4 flex items-center">
            <input type="checkbox" name={"fields[#{@field["id"]}][required]"} checked={@field["required"]} value="true"
                   phx-click="update-field" phx-value-id={@field["id"]} phx-value-attr="required"
                   phx-value-value={to_string(!@field["required"])} id={"req_#{@field["id"]}"}
                   class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded cursor-pointer" />
            <label for={"req_#{@field["id"]}"} class="ml-2 block text-sm font-medium text-gray-700 cursor-pointer">
              Required
            </label>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
