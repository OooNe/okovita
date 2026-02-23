defmodule Okovita.FieldTypes.Textarea.Editor do
  @moduledoc "Editor component for the `textarea` field type."
  use Phoenix.Component

  attr :name, :string, required: true
  attr :value, :string, default: ""
  attr :rows, :integer, default: 5

  def render(assigns) do
    ~H"""
    <textarea
      name={@name}
      rows={@rows}
      class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm
             placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500
             sm:text-sm font-sans"
    ><%= @value %></textarea>
    """
  end
end
