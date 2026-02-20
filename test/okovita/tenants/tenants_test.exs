defmodule Okovita.TenantsTest do
  use Okovita.DataCase, async: false

  alias Okovita.Tenants
  alias Okovita.Tenants.Tenant

  # Track created tenant schemas for cleanup
  setup do
    on_exit(fn ->
      # Clean up any tenant schemas created during tests
      {:ok, %{rows: rows}} =
        Okovita.Repo.query(
          "SELECT schema_name FROM information_schema.schemata WHERE schema_name LIKE 'tenant_%'"
        )

      for [schema_name] <- rows do
        Okovita.Repo.query("DROP SCHEMA \"#{schema_name}\" CASCADE")
      end

      # Also clean up tenant records directly (bypassing sandbox rollback since DDL commits)
      Okovita.Repo.query("DELETE FROM tenants")
    end)

    :ok
  end

  describe "create_tenant/1" do
    test "creates a tenant with schema and migrations" do
      attrs = %{name: "Acme Corp", slug: "acme"}
      assert {:ok, %{tenant: tenant, raw_api_key: raw_key}} = Tenants.create_tenant(attrs)

      assert tenant.name == "Acme Corp"
      assert tenant.slug == "acme"
      assert tenant.status == :active
      assert is_nil(tenant.deleted_at)
      assert is_binary(raw_key)
      assert String.length(raw_key) > 0

      # Verify tenant schema was created
      prefix = Tenants.tenant_prefix(tenant)

      result =
        Okovita.Repo.query(
          "SELECT schema_name FROM information_schema.schemata WHERE schema_name = '#{prefix}'"
        )

      assert {:ok, %{num_rows: 1}} = result

      # Verify tenant tables exist in the schema
      result =
        Okovita.Repo.query(
          "SELECT table_name FROM information_schema.tables WHERE table_schema = '#{prefix}' ORDER BY table_name"
        )

      assert {:ok, %{rows: rows}} = result
      table_names = Enum.map(rows, fn [name] -> name end)
      assert "content_entries" in table_names
      assert "content_models" in table_names
      assert "timeline" in table_names
    end

    test "returns error for invalid attrs" do
      assert {:error, changeset} = Tenants.create_tenant(%{name: "", slug: ""})
      assert %{name: ["can't be blank"], slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error for duplicate slug" do
      attrs = %{name: "First", slug: "duplicate"}
      assert {:ok, _} = Tenants.create_tenant(attrs)

      attrs2 = %{name: "Second", slug: "duplicate"}
      assert {:error, changeset} = Tenants.create_tenant(attrs2)
      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end

    test "validates slug format" do
      # Uppercase not allowed
      assert {:error, changeset} = Tenants.create_tenant(%{name: "Test", slug: "UPPER"})
      assert %{slug: [_]} = errors_on(changeset)

      # Spaces not allowed
      assert {:error, changeset} = Tenants.create_tenant(%{name: "Test", slug: "has space"})
      assert %{slug: [_]} = errors_on(changeset)

      # Hyphens OK in the middle
      assert {:ok, _} = Tenants.create_tenant(%{name: "Test", slug: "my-tenant"})
    end
  end

  describe "suspend_tenant/1" do
    test "suspends an active tenant" do
      {:ok, %{tenant: tenant}} = Tenants.create_tenant(%{name: "To Suspend", slug: "suspend-me"})
      assert {:ok, suspended} = Tenants.suspend_tenant(tenant.id)
      assert suspended.status == :suspended
    end

    test "returns error for non-existent tenant" do
      assert {:error, :not_found} = Tenants.suspend_tenant(Ecto.UUID.generate())
    end
  end

  describe "delete_tenant/1" do
    test "soft-deletes a tenant (sets deleted_at and status)" do
      {:ok, %{tenant: tenant}} = Tenants.create_tenant(%{name: "To Delete", slug: "delete-me"})
      assert {:ok, deleted} = Tenants.delete_tenant(tenant.id)
      assert deleted.status == :suspended
      refute is_nil(deleted.deleted_at)
    end

    test "allows reusing slug after soft-delete" do
      {:ok, %{tenant: tenant}} = Tenants.create_tenant(%{name: "First", slug: "reuse-slug"})
      assert {:ok, _} = Tenants.delete_tenant(tenant.id)

      # Same slug should now be available
      assert {:ok, _} = Tenants.create_tenant(%{name: "Second", slug: "reuse-slug"})
    end

    test "returns error for non-existent tenant" do
      assert {:error, :not_found} = Tenants.delete_tenant(Ecto.UUID.generate())
    end
  end

  describe "get_tenant_by_api_key/1" do
    test "returns tenant for valid API key" do
      {:ok, %{tenant: tenant, raw_api_key: raw_key}} =
        Tenants.create_tenant(%{name: "API Test", slug: "api-test"})

      assert {:ok, found} = Tenants.get_tenant_by_api_key(raw_key)
      assert found.id == tenant.id
    end

    test "returns :not_found for invalid API key" do
      {:ok, _} = Tenants.create_tenant(%{name: "API Test", slug: "api-test2"})
      assert {:error, :not_found} = Tenants.get_tenant_by_api_key("invalid-key")
    end

    test "returns :suspended for suspended tenant" do
      {:ok, %{tenant: tenant, raw_api_key: raw_key}} =
        Tenants.create_tenant(%{name: "Suspended", slug: "suspended-tenant"})

      Tenants.suspend_tenant(tenant.id)
      assert {:error, :suspended} = Tenants.get_tenant_by_api_key(raw_key)
    end

    test "returns :not_found for nil or empty key" do
      assert {:error, :not_found} = Tenants.get_tenant_by_api_key(nil)
      assert {:error, :not_found} = Tenants.get_tenant_by_api_key("")
    end
  end

  describe "list_tenants/0" do
    test "returns only non-deleted tenants" do
      {:ok, %{tenant: t1}} = Tenants.create_tenant(%{name: "Active", slug: "active"})
      {:ok, %{tenant: t2}} = Tenants.create_tenant(%{name: "Deleted", slug: "deleted"})
      Tenants.delete_tenant(t2.id)

      tenants = Tenants.list_tenants()
      ids = Enum.map(tenants, & &1.id)
      assert t1.id in ids
      refute t2.id in ids
    end
  end

  describe "tenant_prefix/1" do
    test "returns correct prefix for tenant struct" do
      tenant = %Tenant{id: "abc-123"}
      assert Tenants.tenant_prefix(tenant) == "tenant_abc-123"
    end

    test "returns correct prefix for string id" do
      assert Tenants.tenant_prefix("abc-123") == "tenant_abc-123"
    end
  end
end
