defmodule Okovita.FieldTypes.Url.Editor do
  @moduledoc "Editor component for the `url` field type."
  use Phoenix.Component

  attr :name, :string, required: true
  attr :value, :map, default: nil

  def render(assigns) do
    assigns =
      assign(assigns,
        label_val: get_in(assigns.value || %{}, ["label"]) || "",
        url_val: get_in(assigns.value || %{}, ["url"]) || ""
      )

    ~H"""
    <div class="flex gap-3">
      <input
        type="text"
        name={"#{@name}[label]"}
        value={@label_val}
        placeholder="Tekst linku"
        class="appearance-none block w-1/3 px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm font-sans"
      />
      <input
        type="url"
        name={"#{@name}[url]"}
        value={@url_val}
        placeholder="https://example.com"
        class="appearance-none block flex-1 px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm font-sans"
      />
    </div>
    """
  end
end
