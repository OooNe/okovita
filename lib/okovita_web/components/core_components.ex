defmodule OkovitaWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  This module encapsulates simple and reusable UI elements (inputs, buttons,
  labels) promoting consistency across the admin panel.
  """
  use Phoenix.Component

  @doc """
  Renders a simple styled button.

  ## Examples

      <.button>Send!</.button>
      <.button type="button" phx-click="go">Go</.button>
      <.button variant="danger">Delete</.button>
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :variant, :string, default: "primary", values: ["primary", "secondary", "danger"]
  attr :rest, :global, include: ~w(disabled form name value phx-click phx-value-id title)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex items-center justify-center rounded-md px-4 py-2 text-sm font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2",
        @variant == "primary" && "bg-indigo-600 text-white hover:bg-indigo-700 focus:ring-indigo-500",
        @variant == "secondary" && "bg-gray-500 text-white hover:bg-gray-600 focus:ring-gray-500",
        @variant == "danger" && "bg-red-50 text-red-600 border border-red-200 hover:bg-red-100 focus:ring-red-500",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders an input with label and potential error messages.
  Supports standard input types.
  """
  attr :id, :string, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values:
      ~w(checkbox color date datetime-local email file hidden month number password range radio search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"

  attr :options, :list,
    default: [],
    doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"

  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :string, default: nil

  attr :rest, :global,
    include:
      ~w(accept autocomplete capture cols disabled form list max maxlength min minlength multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class={["flex items-center gap-2", @class]}>
      <input
        type="checkbox"
        id={@id}
        name={@name}
        value="true"
        checked={@checked}
        class="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600"
        {@rest}
      />
      <.label for={@id} class="!mb-0"><%= @label %></.label>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class={["flex flex-col gap-1", @class]}>
      <.label for={@id}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class="block w-full rounded-md border-gray-300 py-1.5 text-gray-900 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm sm:leading-6"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
        <%= render_slot(@inner_block) %>
      </select>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class={["flex flex-col gap-1", @class]}>
      <.label for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
          @errors != [] && "ring-red-300 focus:ring-red-500"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class={["block text-sm font-medium leading-6 text-gray-900", @class]}>
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-1 text-sm text-red-600 flex gap-2 text-sm leading-6">
      <span class="font-medium">Error:</span> <%= render_slot(@inner_block) %>
    </p>
    """
  end

  # Default error translation for UI feedback.
  if Code.ensure_loaded?(OkovitaWeb.CoreComponents) do
    # Simple fallback since we don't have Gettext set up globally directly easily callable here.
    def translate_error({msg, _opts}), do: msg
  else
    def translate_error({msg, _opts}), do: msg
  end
end
