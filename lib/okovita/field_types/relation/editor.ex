defmodule Okovita.FieldTypes.Relation.Editor do
  @moduledoc "Editor component for the `relation` field type."
  use Phoenix.Component

  attr :name, :string, required: true
  attr :value, :string, default: ""
  # [{label, entry_id}]
  attr :options, :list, default: []

  def render(assigns) do
    ~H"""
    <select
      name={@name}
      class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none
             focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md bg-white"
    >
      <option value="">Select an entry...</option>
      <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
    </select>
    """
  end
end
