defmodule Okovita.Pipeline.Behaviour do
  @moduledoc """
  Behaviour for sync/async pipeline stages.

  Each pipeline module implements `apply/2` which transforms a value.
  """

  @doc """
  Applies the pipeline transformation to a value.

  `options` is a map of options for the pipeline (currently unused by built-in pipelines).
  Returns `{:ok, transformed_value}` or `{:error, reason}`.
  """
  @callback apply(value :: any(), options :: map()) :: {:ok, any()} | {:error, String.t()}
end
