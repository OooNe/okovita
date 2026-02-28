defmodule Okovita.Content.ContentTest do
  use Okovita.DataCase, async: false

  alias Okovita.Content
  alias Okovita.Tenants

  @blog_schema %{
    "title" => %{
      "field_type" => "text",
      "label" => "Title",
      "required" => true,
      "max_length" => 200
    },
    "body" => %{"field_type" => "textarea", "label" => "Body", "required" => true},
    "status" => %{
      "field_type" => "enum",
      "label" => "Status",
      "required" => true,
      "one_of" => ["draft", "published", "archived"]
    }
  }

  setup do
    {:ok, %{tenant: tenant}} =
      Tenants.create_tenant(%{name: "Content Test", slug: "content-test"})

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

    %{prefix: prefix, tenant: tenant}
  end

  # ── Model CRUD ────────────────────────────────────────────────────

  describe "create_model/3" do
    test "creates a model with valid schema_definition", %{prefix: prefix} do
      attrs = %{slug: "blog-post", name: "Blog Post", schema_definition: @blog_schema}
      assert {:ok, model} = Content.create_model(attrs, prefix)
      assert model.slug == "blog-post"
      assert model.name == "Blog Post"
      assert model.schema_definition == @blog_schema
    end

    test "returns error for invalid schema_definition", %{prefix: prefix} do
      bad_schema = %{"field" => %{"label" => "X", "required" => false}}
      attrs = %{slug: "bad", name: "Bad", schema_definition: bad_schema}
      assert {:error, changeset} = Content.create_model(attrs, prefix)
      refute changeset.valid?
    end

    test "returns error for missing fields", %{prefix: prefix} do
      assert {:error, changeset} = Content.create_model(%{}, prefix)
      refute changeset.valid?
    end

    test "enforces unique slug", %{prefix: prefix} do
      attrs = %{slug: "unique-slug", name: "First", schema_definition: @blog_schema}
      assert {:ok, _} = Content.create_model(attrs, prefix)

      attrs2 = %{slug: "unique-slug", name: "Second", schema_definition: @blog_schema}
      assert {:error, _} = Content.create_model(attrs2, prefix)
    end
  end

  describe "update_model/4" do
    test "updates model name", %{prefix: prefix} do
      {:ok, model} =
        Content.create_model(
          %{slug: "post", name: "Post", schema_definition: @blog_schema},
          prefix
        )

      assert {:ok, updated} = Content.update_model(model.id, %{name: "Updated Post"}, prefix)
      assert updated.name == "Updated Post"
    end

    test "returns :not_found for missing model", %{prefix: prefix} do
      assert {:error, :not_found} =
               Content.update_model(Ecto.UUID.generate(), %{name: "X"}, prefix)
    end
  end

  describe "list_models/1 and get_model_by_slug/2" do
    test "lists and looks up models", %{prefix: prefix} do
      {:ok, _} =
        Content.create_model(
          %{slug: "articles", name: "Articles", schema_definition: @blog_schema},
          prefix
        )

      {:ok, _} =
        Content.create_model(
          %{slug: "pages", name: "Pages", schema_definition: @blog_schema},
          prefix
        )

      models = Content.list_models(prefix)
      assert length(models) == 2

      assert %{slug: "articles"} = Content.get_model_by_slug("articles", prefix)
      assert is_nil(Content.get_model_by_slug("nonexistent", prefix))
    end
  end

  # ── Entry CRUD ────────────────────────────────────────────────────

  describe "create_entry/4" do
    setup %{prefix: prefix} do
      {:ok, model} =
        Content.create_model(
          %{slug: "blog", name: "Blog", schema_definition: @blog_schema},
          prefix
        )

      %{model: model}
    end

    test "creates entry with valid data", %{prefix: prefix, model: model} do
      attrs = %{
        slug: "first-post",
        data: %{"title" => "First Post", "body" => "Hello World", "status" => "draft"}
      }

      assert {:ok, entry} = Content.create_entry(model.id, attrs, prefix)
      assert entry.slug == "first-post"
      assert entry.data["title"] == "First Post"
      assert entry.model_id == model.id
    end

    test "returns error for invalid data (missing required fields)", %{
      prefix: prefix,
      model: model
    } do
      attrs = %{slug: "bad-post", data: %{"title" => "No Body"}}
      assert {:error, _} = Content.create_entry(model.id, attrs, prefix)
    end

    test "returns error for invalid enum value", %{prefix: prefix, model: model} do
      attrs = %{
        slug: "bad-enum",
        data: %{"title" => "Post", "body" => "Body", "status" => "invalid_status"}
      }

      assert {:error, _} = Content.create_entry(model.id, attrs, prefix)
    end

    test "returns :model_not_found for missing model", %{prefix: prefix} do
      attrs = %{slug: "orphan", data: %{"title" => "X", "body" => "Y", "status" => "draft"}}

      assert {:error, :model_not_found} =
               Content.create_entry(Ecto.UUID.generate(), attrs, prefix)
    end
  end

  describe "update_entry/5" do
    setup %{prefix: prefix} do
      {:ok, model} =
        Content.create_model(
          %{slug: "news", name: "News", schema_definition: @blog_schema},
          prefix
        )

      {:ok, entry} =
        Content.create_entry(
          model.id,
          %{
            slug: "news-1",
            data: %{"title" => "News 1", "body" => "Content", "status" => "draft"}
          },
          prefix
        )

      %{model: model, entry: entry}
    end

    test "updates entry data", %{prefix: prefix, model: model, entry: entry} do
      new_data = %{"title" => "Updated News", "body" => "New Content", "status" => "published"}
      assert {:ok, updated} = Content.update_entry(entry.id, model.id, %{data: new_data}, prefix)
      assert updated.data["title"] == "Updated News"
      assert updated.data["status"] == "published"
    end

    test "returns :not_found for missing entry", %{prefix: prefix, model: model} do
      assert {:error, :not_found} =
               Content.update_entry(Ecto.UUID.generate(), model.id, %{}, prefix)
    end
  end

  describe "delete_entry/3" do
    setup %{prefix: prefix} do
      {:ok, model} =
        Content.create_model(
          %{slug: "temp", name: "Temp", schema_definition: @blog_schema},
          prefix
        )

      {:ok, entry} =
        Content.create_entry(
          model.id,
          %{
            slug: "to-delete",
            data: %{"title" => "Delete Me", "body" => "Content", "status" => "draft"}
          },
          prefix
        )

      %{model: model, entry: entry}
    end

    test "deletes an entry", %{prefix: prefix, entry: entry} do
      assert {:ok, deleted} = Content.delete_entry(entry.id, prefix)
      assert deleted.id == entry.id
      assert is_nil(Content.get_entry(entry.id, prefix))
    end

    test "returns :not_found for missing entry", %{prefix: prefix} do
      assert {:error, :not_found} = Content.delete_entry(Ecto.UUID.generate(), prefix)
    end
  end

  describe "list_entries/2" do
    test "lists entries for a model", %{prefix: prefix} do
      {:ok, model} =
        Content.create_model(
          %{slug: "listing", name: "Listing", schema_definition: @blog_schema},
          prefix
        )

      for i <- 1..3 do
        Content.create_entry(
          model.id,
          %{
            slug: "entry-#{i}",
            data: %{"title" => "Entry #{i}", "body" => "Body #{i}", "status" => "draft"}
          },
          prefix
        )
      end

      entries = Content.list_entries(model.id, prefix)
      assert length(entries) == 3
    end
  end
end
