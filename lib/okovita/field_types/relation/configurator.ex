defmodule Okovita.FieldTypes.Relation.Configurator do
  @moduledoc """
  Configuration UI component for the Relation field type in ModelBuilder.
  """
  use Phoenix.Component
  import OkovitaWeb.CoreComponents

  def render(assigns) do
    ~H"""
    <div>
      <.input type="select" name={"fields[#{@field["id"]}][target_model]"} label="Target Model"
             value={@field["target_model"]} prompt="-- Select Model --" required
             options={@available_models |> Enum.reject(fn m -> @model && m.id == @model.id end) |> Enum.map(&{&1.name, &1.slug})}
             phx-change="update-field" phx-value-id={@field["id"]} phx-value-attr="target_model" />
    </div>
    """
  end
end
