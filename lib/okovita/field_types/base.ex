defmodule Okovita.FieldTypes.Base do
  @moduledoc """
  Convenience macro for implementing `Okovita.FieldTypes.Behaviour`.

  Injects three defaults (all overridable):

  - `@behaviour Okovita.FieldTypes.Behaviour`
  - `validate/3` — no-op passthrough
  - `editor_component/0` — returns `__MODULE__.Editor`

  ## Usage

      defmodule Okovita.FieldTypes.Text do
        use Okovita.FieldTypes.Base

        @impl true
        def primitive_type, do: :string

        @impl true
        def cast(value) when is_binary(value), do: {:ok, value}
        def cast(nil), do: {:ok, nil}
        def cast(_), do: :error

        # validate/3 and editor_component/0 inherited from Base
      end

  ## Overriding the editor

  If the editor lives in a non-standard module, override explicitly:

      @impl true
      def editor_component, do: MyApp.CustomEditor
  """

  @spec __using__(any()) ::
          {:__block__, [],
           [{:@, [...], [...]} | {:def, [...], [...]} | {:defoverridable, [...], [...]}, ...]}
  defmacro __using__(_opts) do
    quote do
      @behaviour Okovita.FieldTypes.Behaviour

      @impl Okovita.FieldTypes.Behaviour
      def editor_component, do: Module.concat(__MODULE__, Editor)
      defoverridable editor_component: 0

      @impl Okovita.FieldTypes.Behaviour
      def validate(changeset, _field_name, _options), do: changeset
      defoverridable validate: 3
    end
  end
end
