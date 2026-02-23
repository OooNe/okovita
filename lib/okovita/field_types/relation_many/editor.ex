defmodule Okovita.FieldTypes.RelationMany.Editor do
  @moduledoc "Editor component for the `relation_many` field type."
  use Phoenix.Component

  attr :name, :string, required: true
  # current list of selected UUID strings
  attr :value, :list, default: []
  # [{label, entry_id}] — same convention as Relation.Editor
  attr :options, :list, default: []

  def render(assigns) do
    ~H"""
    <%!-- Hidden input ensures an empty submission (no options selected) is preserved --%>
    <input type="hidden" name={@name <> "[]"} value="" />
    <select
      name={@name <> "[]"}
      multiple
      class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none
             focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md bg-white
             min-h-[8rem]"
    >
      <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
    </select>
    """
  end
end
