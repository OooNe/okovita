defmodule OkovitaWeb.Plugs.TenantPlug do
  @moduledoc """
  Plug that authenticates API requests via the `x-api-key` header.

  On success: assigns `conn.assigns.tenant` and `conn.assigns.tenant_prefix`.
  On failure: halts with 401 (not found) or 403 (suspended).
  """
  import Plug.Conn
  alias Okovita.Tenants

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    with [api_key | _] <- get_req_header(conn, "x-api-key"),
         {:ok, tenant} <- Tenants.get_tenant_by_api_key(api_key) do
      conn
      |> assign(:tenant, tenant)
      |> assign(:tenant_prefix, Tenants.tenant_prefix(tenant))
    else
      [] ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{errors: [%{message: "Missing API key"}]}))
        |> halt()

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{errors: [%{message: "Invalid API key"}]}))
        |> halt()

      {:error, :suspended} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{errors: [%{message: "Tenant suspended"}]}))
        |> halt()
    end
  end
end
