defmodule Okovita.FieldTypes.RichText.Editor do
  @moduledoc """
  Editor component for the `rich_text` field type.

  Renders a div with `phx-hook="RichTextEditor"` that bridges to a JavaScript
  rich text editor (Tiptap / ProseMirror). The current value is passed as
  serialized JSON. The hook writes the updated JSON back to a hidden input
  on change, which is submitted with the form.

  ## JavaScript hook contract

  The `RichTextEditor` hook must:
  1. Read `el.dataset.value` on mount and initialize the editor with that JSON.
  2. On every editor change, write the updated document JSON to the hidden
     `<input id="rte-input-{name}">` as a string.
  3. Destroy the editor on `beforeUpdate` / `destroyed` lifecycle callbacks.
  """
  use Phoenix.Component

  attr :name, :string, required: true
  attr :value, :map, default: %{}

  def render(assigns) do
    encoded = Jason.encode!(assigns.value || %{})
    assigns = assign(assigns, :encoded_value, encoded)

    ~H"""
    <div
      id={"rte-#{@name}"}
      phx-hook="RichTextEditor"
      data-field={@name}
      data-value={@encoded_value}
      class="min-h-[200px] border border-gray-300 rounded-md focus-within:ring-1
             focus-within:ring-indigo-500 focus-within:border-indigo-500"
    >
      <%!-- JavaScript hook mounts editor here --%>
      <input
        type="hidden"
        name={@name}
        id={"rte-input-#{@name}"}
        value={@encoded_value}
      />
    </div>
    """
  end
end
