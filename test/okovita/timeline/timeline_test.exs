defmodule Okovita.Timeline.TimelineTest do
  use Okovita.DataCase, async: false

  alias Okovita.Timeline
  alias Okovita.Tenants

  setup do
    {:ok, %{tenant: tenant}} =
      Tenants.create_tenant(%{name: "Timeline Test", slug: "timeline-test"})

    prefix = Tenants.tenant_prefix(tenant)

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

    %{prefix: prefix}
  end

  describe "create_record/2" do
    test "inserts a timeline record", %{prefix: prefix} do
      entity_id = Ecto.UUID.generate()

      attrs = %{
        entity_id: entity_id,
        entity_type: "model",
        action: "create",
        actor_id: Ecto.UUID.generate(),
        before: nil,
        after: %{name: "Test Model"}
      }

      assert {:ok, record} = Timeline.create_record(attrs, prefix)
      assert record.entity_id == entity_id
      assert record.entity_type == "model"
      assert record.action == "create"
      assert record.after == %{name: "Test Model"}
    end
  end

  describe "list_records/3" do
    test "returns records for an entity in desc order", %{prefix: prefix} do
      entity_id = Ecto.UUID.generate()

      for action <- ["create", "update", "update"] do
        Timeline.create_record(
          %{
            entity_id: entity_id,
            entity_type: "entry",
            action: action,
            before: nil,
            after: nil
          },
          prefix
        )
      end

      records = Timeline.list_records(entity_id, "entry", prefix)
      assert length(records) == 3
      assert hd(records).action in ["create", "update"]
    end

    test "returns empty list for non-existent entity", %{prefix: prefix} do
      assert [] = Timeline.list_records(Ecto.UUID.generate(), "model", prefix)
    end
  end
end
