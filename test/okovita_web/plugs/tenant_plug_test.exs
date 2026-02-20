defmodule OkovitaWeb.Plugs.TenantPlugTest do
  use OkovitaWeb.ConnCase, async: false

  alias Okovita.Tenants
  alias OkovitaWeb.Plugs.TenantPlug

  setup do
    {:ok, %{tenant: tenant, raw_api_key: raw_key}} =
      Tenants.create_tenant(%{name: "Plug Test", slug: "plug-test"})

    on_exit(fn ->
      {:ok, %{rows: rows}} =
        Okovita.Repo.query(
          "SELECT schema_name FROM information_schema.schemata WHERE schema_name LIKE 'tenant_%'"
        )

      for [schema_name] <- rows do
        Okovita.Repo.query("DROP SCHEMA \"#{schema_name}\" CASCADE")
      end

      Okovita.Repo.query("DELETE FROM tenants")
    end)

    %{tenant: tenant, raw_api_key: raw_key}
  end

  describe "call/2" do
    test "assigns tenant and prefix for valid API key", %{tenant: tenant, raw_api_key: raw_key} do
      conn =
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> TenantPlug.call([])

      assert conn.assigns.tenant.id == tenant.id
      assert conn.assigns.tenant_prefix == "tenant_#{tenant.id}"
      refute conn.halted
    end

    test "returns 401 when no API key header" do
      conn =
        build_conn()
        |> TenantPlug.call([])

      assert conn.status == 401
      assert conn.halted
      body = Jason.decode!(conn.resp_body)
      assert hd(body["errors"])["message"] =~ "Missing"
    end

    test "returns 401 for invalid API key" do
      conn =
        build_conn()
        |> put_req_header("x-api-key", "invalid-key")
        |> TenantPlug.call([])

      assert conn.status == 401
      assert conn.halted
      body = Jason.decode!(conn.resp_body)
      assert hd(body["errors"])["message"] =~ "Invalid"
    end

    test "returns 403 for suspended tenant", %{tenant: tenant, raw_api_key: raw_key} do
      {:ok, _} = Tenants.suspend_tenant(tenant.id)

      conn =
        build_conn()
        |> put_req_header("x-api-key", raw_key)
        |> TenantPlug.call([])

      assert conn.status == 403
      assert conn.halted
      body = Jason.decode!(conn.resp_body)
      assert hd(body["errors"])["message"] =~ "suspended"
    end
  end
end
