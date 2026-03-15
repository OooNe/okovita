defmodule Okovita.FieldTypes.List.Configurator do
  @moduledoc "Model-builder configurator for the `list` field type."
  use Phoenix.Component
  import OkovitaWeb.CoreComponents

  alias Okovita.FieldTypes.Registry

  attr :field, :map, required: true
  attr :model, :any, default: nil
  attr :available_models, :list, default: []

  def render(assigns) do
    options =
      Registry.list_compatible_types()
      |> Enum.map(fn name -> {String.capitalize(name), name} end)

    assigns = Map.put(assigns, :subtype_options, options)

    ~H"""
    <.input
      type="select"
      name={"fields[#{@field["id"]}][list_subtype]"}
      label="Item type"
      value={@field["list_subtype"] || "text"}
      options={@subtype_options}
      phx-change="update-field"
      phx-value-id={@field["id"]}
      phx-value-attr="list_subtype"
    />
    """
  end
end
