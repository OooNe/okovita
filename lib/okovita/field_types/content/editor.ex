defmodule Okovita.FieldTypes.Content.Editor do
  @moduledoc "Editor component for the `content` field type using CKEditor 5."
  use Phoenix.Component
  use CKEditor5

  attr :name, :string, required: true
  attr :value, :string, default: ""

  def render(assigns) do
    assigns = assign_new(assigns, :upload_url, fn -> nil end)

    ~H"""
    <div>
      <.ckeditor
        name={@name}
        type="classic"
        preset="markdown"
        value={@value}
        upload_url={@upload_url}
      />
    </div>
    """
  end
end
