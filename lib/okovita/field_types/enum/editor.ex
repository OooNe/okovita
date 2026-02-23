defmodule Okovita.FieldTypes.Enum.Editor do
  @moduledoc "Editor component for the `enum` field type."
  use Phoenix.Component

  attr :name, :string, required: true
  attr :value, :string, default: ""
  # list of string values, or [{label, value}] tuples
  attr :options, :list, required: true

  def render(assigns) do
    ~H"""
    <select
      name={@name}
      class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none
             focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md bg-white"
    >
      <option value="">Select...</option>
      <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
    </select>
    """
  end
end
