defmodule OkovitaWeb.Transports.REST.Controllers.EntryControllerTest do
  use OkovitaWeb.ConnCase, async: false

  alias Okovita.{Content, Tenants}

  @blog_schema %{
    "title" => %{"field_type" => "text", "label" => "Title", "required" => true},
    "body" => %{"field_type" => "textarea", "label" => "Body", "required" => true}
  }

  setup %{conn: conn} do
    {:ok, %{tenant: tenant, raw_api_key: api_key}} =
      Tenants.create_tenant(%{name: "Entry API Test", slug: "entry-api"})

    prefix = Tenants.tenant_prefix(tenant)

    {:ok, model} =
      Content.create_model(
        %{slug: "articles", name: "Articles", schema_definition: @blog_schema},
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

    conn = put_req_header(conn, "x-api-key", api_key)
    %{conn: conn, prefix: prefix, model: model, api_key: api_key}
  end

  describe "POST /api/v1/models/:model_slug/entries" do
    test "creates an entry", %{conn: conn} do
      params = %{
        "slug" => "my-article",
        "data" => %{"title" => "Hello", "body" => "World"}
      }

      conn = post(conn, "/api/v1/models/articles/entries", params)

      assert %{"id" => _, "title" => "Hello", "body" => "World"} = json_response(conn, 201)
    end

    test "returns 422 on validation error", %{conn: conn} do
      params = %{"slug" => "bad", "data" => %{"title" => "No body"}}
      conn = post(conn, "/api/v1/models/articles/entries", params)
      assert json_response(conn, 422)["error"]
    end

    test "returns 404 for unknown model", %{conn: conn} do
      params = %{"slug" => "x", "data" => %{}}
      conn = post(conn, "/api/v1/models/nonexistent/entries", params)
      assert json_response(conn, 404)["error"]
    end

    test "includes metadata when withMetadata=true", %{conn: conn} do
      params = %{
        "slug" => "my-flat-article",
        "data" => %{"title" => "Flat", "body" => "Data"}
      }

      conn = post(conn, "/api/v1/models/articles/entries?withMetadata=true", params)

      assert %{
               "metadata" => %{"slug" => "my-flat-article"},
               "data" => %{"id" => _, "title" => "Flat", "body" => "Data"}
             } = json_response(conn, 201)
    end
  end

  describe "GET /api/v1/models/:model_slug/entries" do
    test "lists entries", %{conn: conn, prefix: prefix, model: model} do
      Content.create_entry(
        model.id,
        %{
          slug: "post-1",
          data: %{"title" => "One", "body" => "Content 1"}
        },
        prefix
      )

      conn = get(conn, "/api/v1/models/articles/entries")
      assert entries = json_response(conn, 200)
      assert is_list(entries)
      assert length(entries) == 1
    end
  end

  describe "GET /api/v1/models/:model_slug/entries/:id" do
    test "shows an entry", %{conn: conn, prefix: prefix, model: model} do
      {:ok, entry} =
        Content.create_entry(
          model.id,
          %{
            slug: "show-me",
            data: %{"title" => "Show", "body" => "Me"}
          },
          prefix
        )

      conn = get(conn, "/api/v1/models/articles/entries/#{entry.id}")

      assert %{"id" => entry_id, "title" => "Show", "body" => "Me"} = json_response(conn, 200)
      assert entry_id == entry.id
    end

    test "returns 404 for unknown entry", %{conn: conn} do
      conn = get(conn, "/api/v1/models/articles/entries/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"]
    end

    test "includes metadata when withMetadata=1", %{conn: conn, prefix: prefix, model: model} do
      {:ok, entry} =
        Content.create_entry(
          model.id,
          %{
            slug: "show-me-flat",
            data: %{"title" => "Show Flat", "body" => "Me Flat"}
          },
          prefix
        )

      conn = get(conn, "/api/v1/models/articles/entries/#{entry.id}?withMetadata=1")

      assert %{
               "metadata" => %{"slug" => "show-me-flat"},
               "data" => %{"id" => entry_id, "title" => "Show Flat"}
             } = json_response(conn, 200)

      assert entry_id == entry.id
    end
  end

  describe "PUT /api/v1/models/:model_slug/entries/:id" do
    test "updates an entry", %{conn: conn, prefix: prefix, model: model} do
      {:ok, entry} =
        Content.create_entry(
          model.id,
          %{
            slug: "update-me",
            data: %{"title" => "Old", "body" => "Content"}
          },
          prefix
        )

      params = %{"data" => %{"title" => "New Title", "body" => "New Content"}}
      conn = put(conn, "/api/v1/models/articles/entries/#{entry.id}", params)

      assert %{"id" => entry_id, "title" => "New Title", "body" => "New Content"} =
               json_response(conn, 200)

      assert entry_id == entry.id
    end
  end

  describe "DELETE /api/v1/models/:model_slug/entries/:id" do
    test "deletes an entry", %{conn: conn, prefix: prefix, model: model} do
      {:ok, entry} =
        Content.create_entry(
          model.id,
          %{
            slug: "delete-me",
            data: %{"title" => "Bye", "body" => "Content"}
          },
          prefix
        )

      conn = delete(conn, "/api/v1/models/articles/entries/#{entry.id}")
      assert response(conn, 204)
    end

    test "returns 404 for unknown entry", %{conn: conn} do
      conn = delete(conn, "/api/v1/models/articles/entries/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"]
    end
  end

  describe "Relation Population" do
    test "populates relation fields when populate is configured", %{conn: conn, prefix: prefix} do
      # 1. Create target model
      {:ok, author_model} =
        Content.create_model(
          %{
            slug: "authors",
            name: "Authors",
            schema_definition: %{
              "name" => %{"field_type" => "text", "label" => "Name", "required" => true}
            }
          },
          prefix
        )

      # 2. Create entry for the target model
      {:ok, author} =
        Content.create_entry(
          author_model.id,
          %{slug: "john-doe", data: %{"name" => "John Doe"}},
          prefix
        )

      # 3. Create model with a relation
      {:ok, doc_model} =
        Content.create_model(
          %{
            slug: "docs",
            name: "Docs",
            schema_definition: %{
              "author" => %{
                "field_type" => "relation",
                "label" => "Author",
                "target_model" => "authors",
                "required" => false
              }
            }
          },
          prefix
        )

      # 4. Create an entry linking to the author
      {:ok, doc} =
        Content.create_entry(
          doc_model.id,
          %{slug: "doc-1", data: %{"author" => author.id}},
          prefix
        )

      # 5. Fetch the linked entry from `index` and `show`
      conn_index = get(conn, "/api/v1/models/docs/entries?populate=*&withMetadata=true")

      assert [fetched_index_doc] = json_response(conn_index, 200)
      assert fetched_index_doc["data"]["author"]["data"]["id"] == author.id
      assert fetched_index_doc["data"]["author"]["data"]["name"] == "John Doe"
      # metadata was populated with nested object
      assert fetched_index_doc["data"]["author"]["metadata"]["model_slug"] == "authors"

      conn_show = get(conn, "/api/v1/models/docs/entries/#{doc.id}?populate=*&withMetadata=true")
      assert fetched_show_doc = json_response(conn_show, 200)
      assert fetched_show_doc["data"]["author"]["data"]["id"] == author.id
      assert fetched_show_doc["data"]["author"]["data"]["name"] == "John Doe"
    end

    test "ignores population by default preserving original ids", %{conn: conn, prefix: prefix} do
      # 1. Create target model
      {:ok, author_model} =
        Content.create_model(
          %{
            slug: "authors",
            name: "Authors",
            schema_definition: %{
              "name" => %{"field_type" => "text", "label" => "Name", "required" => true}
            }
          },
          prefix
        )

      # 2. Create entry for the target model
      {:ok, author} =
        Content.create_entry(
          author_model.id,
          %{slug: "john-doe", data: %{"name" => "John Doe"}},
          prefix
        )

      # 3. Create model with a relation
      {:ok, doc_model} =
        Content.create_model(
          %{
            slug: "docs",
            name: "Docs",
            schema_definition: %{
              "author" => %{
                "field_type" => "relation",
                "label" => "Author",
                "target_model" => "authors",
                "required" => false
              }
            }
          },
          prefix
        )

      # 4. Create an entry linking to the author
      {:ok, doc} =
        Content.create_entry(
          doc_model.id,
          %{slug: "doc-1", data: %{"author" => author.id}},
          prefix
        )

      # 5. Fetch the linked entry WITHOUT `populate=*`
      conn_index = get(conn, "/api/v1/models/docs/entries")

      assert [fetched_index_doc] = json_response(conn_index, 200)
      # Assert the value is exactly the string ID, not an object
      assert fetched_index_doc["author"]["id"] == author.id

      conn_show = get(conn, "/api/v1/models/docs/entries/#{doc.id}")
      assert fetched_show_doc = json_response(conn_show, 200)
      # Assert the value is exactly the string ID, not an object
      assert fetched_show_doc["author"]["id"] == author.id
    end
  end

  describe "Nested Relations Endpoint" do
    test "lists related children by parent endpoint", %{conn: conn, prefix: prefix} do
      # 1. Create parent model (Author) with no relations
      {:ok, author_model} =
        Content.create_model(
          %{
            slug: "authors",
            name: "Authors",
            schema_definition: %{
              "name" => %{"field_type" => "text", "label" => "Name", "required" => true}
            }
          },
          prefix
        )

      # 2. Create child model (Docs) which points to Authors
      {:ok, doc_model} =
        Content.create_model(
          %{
            slug: "docs",
            name: "Docs",
            schema_definition: %{
              "title" => %{"field_type" => "text", "label" => "Title", "required" => true},
              "author" => %{
                "field_type" => "relation",
                "label" => "Author",
                "target_model" => "authors",
                "required" => false
              }
            }
          },
          prefix
        )

      # 3. Create Parent entry
      {:ok, author} =
        Content.create_entry(
          author_model.id,
          %{slug: "john-doe", data: %{"name" => "John"}},
          prefix
        )

      # 4. Create child entries linking to the author
      {:ok, _doc1} =
        Content.create_entry(
          doc_model.id,
          %{slug: "doc-1", data: %{"title" => "First", "author" => author.id}},
          prefix
        )

      {:ok, _doc2} =
        Content.create_entry(
          doc_model.id,
          %{slug: "doc-2", data: %{"title" => "Second", "author" => author.id}},
          prefix
        )

      # 5. Consume Nested Endpoint (Parent's perspective)
      conn_nested = get(conn, "/api/v1/models/authors/entries/#{author.id}/docs")

      assert nested_resp = json_response(conn_nested, 200)
      assert is_list(nested_resp)
      assert length(nested_resp) == 2

      titles = Enum.map(nested_resp, & &1["title"])
      assert "First" in titles
      assert "Second" in titles
    end
  end

  describe "API requires valid x-api-key" do
    test "returns 401 without api key" do
      conn = build_conn()
      conn = get(conn, "/api/v1/models/articles/entries")
      assert json_response(conn, 401)["errors"]
    end

    test "returns 401 with invalid api key" do
      conn = build_conn() |> put_req_header("x-api-key", "invalid_key")
      conn = get(conn, "/api/v1/models/articles/entries")
      assert json_response(conn, 401)["errors"]
    end
  end
end
