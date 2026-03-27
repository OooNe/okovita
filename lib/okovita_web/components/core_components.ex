defmodule OkovitaWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  This module encapsulates simple and reusable UI elements (inputs, buttons,
  labels) promoting consistency across the admin panel.
  """
  use Phoenix.Component
  alias Phoenix.LiveView.JS

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

  @doc """
  Renders a modal.

  ## Attributes
  - `id` - required id
  - `show` - boolean to control visibility
  - `on_close` - JS command or string event to push when clicking backdrop/close
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_close, :any, default: nil
  slot :inner_block, required: true
  slot :title
  slot :footer

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && JS.show(transition: {"transition-all ease-out duration-300", "opacity-0", "opacity-100"})}
      class={["relative z-50", !@show && "hidden"]}
    >
      <%!-- Backdrop --%>
      <div
        class="fixed inset-0 bg-gray-900/60 backdrop-blur-sm transition-opacity"
        aria-hidden="true"
        phx-click={@on_close}
      />

      <%!-- Modal Panel --%>
      <div class="fixed inset-0 z-10 w-screen overflow-y-auto">
        <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
          <div
            class="relative transform overflow-hidden rounded-2xl bg-white text-left shadow-2xl transition-all sm:my-8 sm:w-full sm:max-w-2xl animate-fade-in-up"
            phx-click-away={@on_close}
          >
            <%!-- Header --%>
            <div :if={render_slot(@title)} class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
              <h3 class="text-lg font-semibold text-gray-900">
                <%= render_slot(@title) %>
              </h3>
              <button
                type="button"
                phx-click={@on_close}
                class="text-gray-400 hover:text-gray-600 transition-colors p-1 rounded-lg hover:bg-gray-100"
              >
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>

            <div class="px-6 py-6">
              <%= render_slot(@inner_block) %>
            </div>

            <%!-- Footer --%>
            <div :if={render_slot(@footer)} class="px-6 py-4 border-t border-gray-100 bg-gray-50/50 flex justify-end gap-3">
              <%= render_slot(@footer) %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix respectively.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  def icon(%{name: "hero-plus"} = assigns) do
    ~H"""
    <svg class={["shrink-0", @class]} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
    </svg>
    """
  end

  def icon(%{name: "hero-x-mark"} = assigns) do
    ~H"""
    <svg class={["shrink-0", @class]} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
    </svg>
    """
  end

  def icon(%{name: "hero-check"} = assigns) do
    ~H"""
    <svg class={["shrink-0", @class]} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
    </svg>
    """
  end

  def icon(%{name: "hero-magnifying-glass"} = assigns) do
    ~H"""
    <svg class={["shrink-0", @class]} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
    </svg>
    """
  end

  def icon(%{name: "hero-trash"} = assigns) do
    ~H"""
    <svg class={["shrink-0", @class]} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
    </svg>
    """
  end

  def icon(%{name: "hero-eye"} = assigns) do
    ~H"""
    <svg class={["shrink-0", @class]} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
    </svg>
    """
  end

  def icon(%{name: "hero-eye-slash"} = assigns) do
    ~H"""
    <svg class={["shrink-0", @class]} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88" />
    </svg>
    """
  end

  def icon(%{name: "hero-crop"} = assigns) do
    ~H"""
    <svg class={["shrink-0", @class]} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M6 3v15m0 0h15M3 6h15v15" />
    </svg>
    """
  end

  def icon(%{name: "hero-arrow-path"} = assigns) do
    ~H"""
    <svg class={["shrink-0", @class]} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99" />
    </svg>
    """
  end

  def icon(%{name: "hero-information-circle"} = assigns) do
    ~H"""
    <svg class={["shrink-0", @class]} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" />
    </svg>
    """
  end

  def icon(%{name: "hero-chevron-right"} = assigns) do
    ~H"""
    <svg class={["shrink-0", @class]} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
    </svg>
    """
  end

  def icon(%{name: "hero-chevron-down"} = assigns) do
    ~H"""
    <svg class={["shrink-0", @class]} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
    </svg>
    """
  end

  def icon(%{name: "hero-arrow-down-tray"} = assigns) do
    ~H"""
    <svg class={["shrink-0", @class]} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" />
    </svg>
    """
  end

  def icon(%{name: "hero-arrow-up-tray"} = assigns) do
    ~H"""
    <svg class={["shrink-0", @class]} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" />
    </svg>
    """
  end

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} {@rest} />
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
