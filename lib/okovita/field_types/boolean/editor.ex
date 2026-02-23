defmodule Okovita.FieldTypes.Boolean.Editor do
  @moduledoc "Editor component for the `boolean` field type."
  use Phoenix.Component

  attr :name, :string, required: true
  attr :value, :any, default: nil

  def render(assigns) do
    assigns = assign(assigns, :checked, assigns.value in [true, "true"])

    ~H"""
    <input
      type="checkbox"
      name={@name}
      value="true"
      checked={@checked}
      class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded cursor-pointer"
    />
    """
  end
end
