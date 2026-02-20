defmodule OkovitaWeb.FallbackController do
  @moduledoc """
  Fallback controller for common error handling in REST controllers.
  """
  use OkovitaWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: %{message: "Not found"}})
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{message: "Validation failed", details: errors}})
  end
end
