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
      data-name={@name}
      class="space-y-2"
    >
      <div data-items class="space-y-3 mb-3">
        <%= if @subtype == "url" do %>
          <%= for {item, index} <- Enum.with_index(@value) do %>
            <div data-item class="flex items-center gap-2">
              <span data-drag-handle class="flex-shrink-0 cursor-move text-gray-300 hover:text-indigo-400 transition-colors">
                <svg class="w-4 h-4" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 3a1.5 1.5 0 110 3 1.5 1.5 0 010-3zM10 8.5a1.5 1.5 0 110 3 1.5 1.5 0 010-3zM10 14a1.5 1.5 0 110 3 1.5 1.5 0 010-3z" clip-rule="evenodd" />
                </svg>
              </span>
              <div class="flex gap-2 flex-1">
                <input
                  type="text"
                  name={"#{@name}[#{index}][label]"}
                  value={if is_map(item), do: item["label"] || "", else: ""}
                  placeholder="Tekst linku"
                  class="block w-1/3 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                />
                <input
                  type="url"
                  name={"#{@name}[#{index}][url]"}
                  value={if is_map(item), do: item["url"] || "", else: ""}
                  placeholder="https://example.com"
                  class="block flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                />
              </div>
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
        <% else %>
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
                  type="text"
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
        <% end %>
      </div>

      <button
        type="button"
        data-add
        class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-indigo-600 bg-white border border-indigo-300 rounded-md shadow-sm hover:bg-indigo-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-1 transition-colors"
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
          <%= if @subtype == "url" do %>
            <div class="flex gap-2 flex-1">
              <input
                type="text"
                data-url-label
                placeholder="Tekst linku"
                class="block w-1/3 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              />
              <input
                type="url"
                data-url-href
                placeholder="https://example.com"
                class="block flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              />
            </div>
          <% else %>
            <%= if @subtype == "textarea" do %>
              <textarea
                name={"#{@name}[]"}
                rows="2"
                class="flex-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm resize-none"
              ></textarea>
            <% else %>
              <input
                type="text"
                name={"#{@name}[]"}
                value=""
                class="flex-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              />
            <% end %>
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
