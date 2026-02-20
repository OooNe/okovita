defmodule OkovitaWeb.Admin.SessionController do
  @moduledoc "Handles admin session creation and destruction."
  use OkovitaWeb, :controller

  def create(conn, %{"admin_id" => admin_id}) do
    conn
    |> put_session(:admin_id, admin_id)
    |> redirect(to: "/admin")
  end

  alias Okovita.Tenants

  def dashboard(conn, _params) do
    case conn.assigns.current_admin do
      %{role: :super_admin} ->
        redirect(conn, to: "/admin/tenants")

      %{role: :tenant_admin, tenant_id: tenant_id} ->
        case Tenants.get_tenant(tenant_id) do
          nil ->
            conn
            |> put_flash(:error, "Teenant not found")
            |> redirect(to: "/admin/login")

          tenant ->
            redirect(conn, to: "/admin/tenants/#{tenant.slug}/models")
        end
    end
  end

  def delete(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: "/admin/login")
  end
end
