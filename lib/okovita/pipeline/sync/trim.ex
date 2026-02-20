defmodule Okovita.Pipeline.Sync.Trim do
  @moduledoc "Sync pipeline that trims whitespace from string values."
  @behaviour Okovita.Pipeline.Behaviour

  @impl true
  def apply(value, _options) when is_binary(value), do: {:ok, String.trim(value)}
  def apply(value, _options), do: {:ok, value}
end
