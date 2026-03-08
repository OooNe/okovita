defmodule Okovita.FieldTypes.RelationMany.Editor do
  @moduledoc "Editor component for the `relation_many` field type."
  use Phoenix.Component
  use OkovitaWeb, :html

  attr :name, :string, required: true
  attr :value, :list, default: []
  attr :options, :list, default: []

  def render(assigns) do
    ~H"""
    <div id={"multiselect-#{@name}"} phx-hook="Multiselect" class="relative">
      <%!-- Hidden real select for form submission --%>
      <select name={@name <> "[]"} multiple class="hidden">
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>

      <%!-- Tags + Add button --%>
      <div data-container class="flex flex-wrap items-center gap-2 py-1">
        <%= for id <- @value do %>
          <% label = Enum.find_value(@options, id, fn {l, i} -> if i == id, do: l end) %>
          <span class="inline-flex items-center gap-1.5 pl-3 pr-2 py-1 bg-indigo-50 text-indigo-700 text-sm font-medium rounded-full border border-indigo-200">
            <%= label %>
            <button type="button" data-id={id} data-remove class="text-indigo-400 hover:text-red-500 focus:outline-none transition-colors flex items-center">
              <svg style="width:16px;height:16px;flex-shrink:0" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
              </svg>
            </button>
          </span>
        <% end %>

        <button
          type="button"
          data-add
          class="inline-flex items-center gap-1 px-3 py-1 text-sm text-gray-500 hover:text-indigo-600 hover:bg-indigo-50 rounded-full border border-dashed border-gray-300 hover:border-indigo-300 transition-colors focus:outline-none"
        >
          <.icon name="hero-plus" class="w-4 h-4" />
          Dodaj
        </button>
      </div>

      <%!-- Dropdown --%>
      <div data-dropdown class="hidden absolute z-50 top-full left-0 mt-1 w-full bg-white border border-gray-200 rounded-lg shadow-lg overflow-hidden">
        <%!-- Search bar --%>
        <div class="flex items-center gap-3 px-4 py-3 border-b border-gray-100 bg-gray-50">
          <.icon name="hero-magnifying-glass" class="w-4 h-4 text-gray-400 shrink-0" />
          <input
            type="text"
            data-search
            placeholder="Szukaj..."
            class="flex-1 bg-transparent border-0 p-0 text-sm text-gray-700 placeholder-gray-400 focus:outline-none focus:ring-0"
            autocomplete="off"
          />
        </div>

        <%!-- Options --%>
        <div class="max-h-64 overflow-y-auto py-1">
          <%= for {label, id} <- @options do %>
            <div
              data-option
              data-id={id}
              style="padding: 10px 16px;"
              class={[
                "flex items-center justify-between text-sm cursor-pointer select-none",
                if(id in @value,
                  do: "bg-indigo-50 text-indigo-700 font-semibold",
                  else: "text-gray-700 hover:bg-gray-50")
              ]}
            >
              <%= label %>
              <.icon :if={id in @value} name="hero-check" class="w-4 h-4 text-indigo-600 shrink-0" />
            </div>
          <% end %>
          <div :if={Enum.empty?(@options)} style="padding: 24px 16px;" class="text-sm text-gray-400 text-center italic">
            Brak opcji do wyboru
          </div>
        </div>
      </div>
    </div>
    """
  end
end
