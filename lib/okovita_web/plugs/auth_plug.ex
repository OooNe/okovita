defmodule OkovitaWeb.Plugs.AuthPlug do
  @moduledoc """
  Plug for admin session authentication.

  Reads `admin_id` from session, loads the admin, and assigns
  `current_admin` and optionally `tenant_prefix` to conn.

  Redirects to login on unauthorized access.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias Okovita.Auth
  alias Okovita.Tenants

  def init(opts), do: opts

  def call(conn, _opts) do
    admin_id = get_session(conn, :admin_id)

    if admin_id do
      case Auth.get_admin(admin_id) do
        nil ->
          conn
          |> clear_session()
          |> redirect(to: "/admin/login")
          |> halt()

        admin ->
          conn
          |> assign(:current_admin, admin)
          |> maybe_assign_tenant_prefix(admin)
      end
    else
      conn
      |> redirect(to: "/admin/login")
      |> halt()
    end
  end

  defp maybe_assign_tenant_prefix(conn, %{role: :tenant_admin, tenant_id: tenant_id}) do
    case Tenants.get_tenant(tenant_id) do
      nil ->
        conn
        |> clear_session()
        |> redirect(to: "/admin/login")
        |> halt()

      tenant ->
        assign(conn, :tenant_prefix, Tenants.tenant_prefix(tenant))
    end
  end

  defp maybe_assign_tenant_prefix(conn, _admin), do: conn
end
