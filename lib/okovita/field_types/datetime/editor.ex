defmodule Okovita.FieldTypes.Datetime.Editor do
  @moduledoc "Editor component for the `datetime` field type."
  use Phoenix.Component

  attr :name, :string, required: true
  attr :value, :any, default: ""

  def render(assigns) do
    # Strip timezone suffix for datetime-local input compatibility
    str_value =
      case assigns.value do
        %DateTime{} = dt ->
          dt
          |> DateTime.to_iso8601()
          |> String.replace(~r/\.\d+Z$/, "")
          |> String.replace("Z", "")

        s when is_binary(s) ->
          s
          |> String.replace(~r/\.\d+Z$/, "")
          |> String.replace("Z", "")

        _ ->
          ""
      end

    assigns = assign(assigns, :str_value, str_value)

    ~H"""
    <input
      type="datetime-local"
      name={@name}
      value={@str_value}
      class="appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm
             placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500
             sm:text-sm"
    />
    """
  end
end
