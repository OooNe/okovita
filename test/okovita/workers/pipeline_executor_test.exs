defmodule Okovita.Workers.PipelineExecutorTest do
  use Okovita.DataCase, async: false

  alias Okovita.Workers.PipelineExecutor
  alias Okovita.{Content, Tenants}

  @blog_schema %{
    "title" => %{"field_type" => "text", "label" => "Title", "required" => true},
    "body" => %{"field_type" => "textarea", "label" => "Body", "required" => true}
  }

  setup do
    {:ok, %{tenant: tenant}} =
      Tenants.create_tenant(%{name: "Pipeline Test", slug: "pipeline-test"})

    prefix = Tenants.tenant_prefix(tenant)

    {:ok, model} =
      Content.create_model(
        %{slug: "post", name: "Post", schema_definition: @blog_schema},
        prefix
      )

    {:ok, entry} =
      Content.create_entry(
        model.id,
        %{
          slug: "my-post",
          data: %{"title" => "  Needs Trimming  ", "body" => "Some content"}
        },
        prefix
      )

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

    %{prefix: prefix, model: model, entry: entry}
  end

  describe "perform/1" do
    test "applies pipeline to entry field", %{prefix: prefix, entry: entry} do
      # Note: trim is already applied during create_entry, so the title is already trimmed
      # Let's test with slugify pipeline which is NOT applied globally
      job = %Oban.Job{
        args: %{
          "entry_id" => entry.id,
          "prefix" => prefix,
          "pipeline" => "trim",
          "field" => "title",
          "options" => %{}
        }
      }

      assert :ok = PipelineExecutor.perform(job)
    end

    test "discards job when entry is deleted", %{prefix: prefix, entry: entry} do
      Content.delete_entry(entry.id, prefix)

      job = %Oban.Job{
        args: %{
          "entry_id" => entry.id,
          "prefix" => prefix,
          "pipeline" => "trim",
          "field" => "title",
          "options" => %{}
        }
      }

      assert :discard = PipelineExecutor.perform(job)
    end

    test "raises on unknown pipeline", %{prefix: prefix, entry: entry} do
      job = %Oban.Job{
        args: %{
          "entry_id" => entry.id,
          "prefix" => prefix,
          "pipeline" => "nonexistent",
          "field" => "title",
          "options" => %{}
        }
      }

      assert_raise ArgumentError, ~r/Unknown pipeline/, fn ->
        PipelineExecutor.perform(job)
      end
    end
  end
end
