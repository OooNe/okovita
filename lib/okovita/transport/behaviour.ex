defmodule Okovita.Transport.Behaviour do
  @moduledoc """
  Behaviour for pluggable transport layers.

  Each transport module implements:
  - `child_spec/1` — returns an optional child spec for supervision
  - `routes/0` — returns a list of route definitions
  """

  @type route :: %{
          method: :get | :post | :put | :patch | :delete,
          path: String.t(),
          controller: module(),
          action: atom()
        }

  @doc "Optional child spec. Return `nil` if the transport doesn't need a supervised process."
  @callback child_spec(opts :: keyword()) :: Supervisor.child_spec() | nil

  @doc "Returns a list of route definitions for this transport."
  @callback routes() :: [route()]
end
