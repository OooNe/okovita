defmodule Okovita.Pipeline.Sync.Slugify do
  @moduledoc """
  Sync pipeline that converts string values to URL-friendly slugs.

  Lowercase, replaces spaces and special characters with hyphens,
  strips non-alphanumeric characters (except hyphens).
  """
  @behaviour Okovita.Pipeline.Behaviour

  @impl true
  def apply(value, _options) when is_binary(value) do
    slug =
      value
      |> String.downcase()
      |> String.replace(~r/[^\w\s-]/u, "")
      |> String.replace(~r/[\s_]+/, "-")
      |> String.replace(~r/-{2,}/, "-")
      |> String.trim("-")

    {:ok, slug}
  end

  def apply(value, _options), do: {:ok, value}
end
