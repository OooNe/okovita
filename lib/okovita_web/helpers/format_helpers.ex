defmodule OkovitaWeb.FormatHelpers do
  @moduledoc """
  Generic presentation helpers for formatting values in templates.
  """

  @doc "Formats a byte size into a human-readable string (B / KB / MB)."
  def format_size(nil), do: "0 B"
  def format_size(size) when size < 1_024, do: "#{size} B"
  def format_size(size) when size < 1_048_576, do: "#{Float.round(size / 1_024, 1)} KB"
  def format_size(size), do: "#{Float.round(size / 1_048_576, 2)} MB"
end
