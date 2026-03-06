defmodule Okovita do
  @moduledoc """
  Okovita keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  @doc \"""
  Returns true if the application environment is configured as :dev
  or the system MIX_ENV is 'dev'.
  """
  def dev? do
    Application.get_env(:okovita, :env) == :dev || System.get_env("MIX_ENV") == "dev"
  end
end
