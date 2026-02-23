defmodule Okovita.FieldTypes.Text.Editor do
  @moduledoc "Editor component for the `text` field type."
  use Phoenix.Component

  attr :name, :string, required: true
  attr :value, :string, default: ""
  attr :placeholder, :string, default: ""

  def render(assigns) do
    ~H"""
    <input
      type="text"
      name={@name}
      value={@value}
      placeholder={@placeholder}
      class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm
             placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500
             sm:text-sm"
    />
    """
  end
end
