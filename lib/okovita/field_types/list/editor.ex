defmodule Okovita.FieldTypes.List.Editor do
  @moduledoc "Editor component for the `list` field type."
  use Phoenix.Component
  use OkovitaWeb, :html

  attr :name, :string, required: true
  attr :value, :list, default: []
  attr :subtype, :string, default: "text"

  def render(assigns) do
    ~H"""
    <div
      id={"list-editor-#{@name}"}
      phx-hook="ListEditor"
      data-subtype={@subtype}
      class="space-y-2"
    >
      <div data-items class="space-y-2">
        <%= for item <- @value do %>
          <div data-item class="flex items-center gap-2">
            <span data-drag-handle class="flex-shrink-0 cursor-move text-gray-300 hover:text-indigo-400 transition-colors">
              <svg class="w-4 h-4" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 3a1.5 1.5 0 110 3 1.5 1.5 0 010-3zM10 8.5a1.5 1.5 0 110 3 1.5 1.5 0 010-3zM10 14a1.5 1.5 0 110 3 1.5 1.5 0 010-3z" clip-rule="evenodd" />
              </svg>
            </span>
            <%= if @subtype == "textarea" do %>
              <textarea
                name={"#{@name}[]"}
                rows="2"
                class="flex-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm resize-none"
              ><%= item %></textarea>
            <% else %>
              <input
                type={if @subtype == "url", do: "url", else: "text"}
                name={"#{@name}[]"}
                value={item}
                class="flex-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              />
            <% end %>
            <button
              type="button"
              data-remove
              class="flex-shrink-0 text-gray-400 hover:text-red-500 transition-colors focus:outline-none"
              title="Usuń"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>
        <% end %>
      </div>

      <button
        type="button"
        data-add
        class="inline-flex items-center gap-1 px-3 py-1 text-sm text-gray-500 hover:text-indigo-600 hover:bg-indigo-50 rounded-full border border-dashed border-gray-300 hover:border-indigo-300 transition-colors focus:outline-none"
      >
        <.icon name="hero-plus" class="w-4 h-4" />
        Dodaj
      </button>

      <template data-item-template>
        <div data-item class="flex items-center gap-2">
          <span data-drag-handle class="flex-shrink-0 cursor-move text-gray-300 hover:text-indigo-400 transition-colors">
            <svg class="w-4 h-4" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 3a1.5 1.5 0 110 3 1.5 1.5 0 010-3zM10 8.5a1.5 1.5 0 110 3 1.5 1.5 0 010-3zM10 14a1.5 1.5 0 110 3 1.5 1.5 0 010-3z" clip-rule="evenodd" />
            </svg>
          </span>
          <%= if @subtype == "textarea" do %>
            <textarea
              name={"#{@name}[]"}
              rows="2"
              class="flex-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm resize-none"
            ></textarea>
          <% else %>
            <input
              type={if @subtype == "url", do: "url", else: "text"}
              name={"#{@name}[]"}
              value=""
              class="flex-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          <% end %>
          <button
            type="button"
            data-remove
            class="flex-shrink-0 text-gray-400 hover:text-red-500 transition-colors focus:outline-none"
            title="Usuń"
          >
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>
      </template>
    </div>
    """
  end
end
