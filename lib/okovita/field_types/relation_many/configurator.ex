defmodule Okovita.FieldTypes.RelationMany.Configurator do
  @moduledoc """
  Configuration UI component for the RelationMany field type in ModelBuilder.
  """
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div>
      <label class="block text-xs font-semibold uppercase tracking-wider text-gray-500 mb-1">Target <span class="text-red-500">*</span></label>
      <select name={"fields[#{@field["id"]}][target_model]"} required
              phx-change="update-field" phx-value-id={@field["id"]} phx-value-attr="target_model"
              class="block w-full px-3 py-2 border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md shadow-sm bg-indigo-50">
        <option value="">-- Model --</option>
        <%= Phoenix.HTML.Form.options_for_select(
              @available_models
              |> Enum.reject(fn m -> @model && m.id == @model.id end)
              |> Enum.map(&{&1.name, &1.slug}),
              @field["target_model"]
            ) %>
      </select>
    </div>
    """
  end
end
