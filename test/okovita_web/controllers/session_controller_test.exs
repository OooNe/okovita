defmodule OkovitaWeb.Admin.SessionControllerTest do
  use OkovitaWeb.ConnCase, async: true
  # alias Okovita.Auth removed

  import Okovita.Factory

  setup do
    super_admin = insert(:admin, role: :super_admin)
    tenant_admin = insert(:tenant_admin)

    %{super: super_admin, tenant: tenant_admin}
  end

  describe "dashboard/2" do
    test "redirects super_admin to /admin/tenants", %{super: admin, conn: conn} do
      conn =
        conn
        |> init_test_session(admin_id: admin.id)
        |> get("/admin")

      assert redirected_to(conn) == "/admin/tenants"
    end

    test "redirects tenant_admin to /admin/tenants/:slug/models", %{tenant: admin, conn: conn} do
      conn =
        conn
        |> init_test_session(admin_id: admin.id)
        |> get("/admin")

      # Need to fetch the tenant slug from the factory-created tenant
      tenant = Okovita.Repo.preload(admin, :tenant).tenant
      assert redirected_to(conn) == "/admin/tenants/#{tenant.slug}/models"
    end

    test "redirects unauthenticated to /admin/login", %{conn: conn} do
      conn = get(conn, "/admin")
      assert redirected_to(conn) == "/admin/login"
    end
  end
end
