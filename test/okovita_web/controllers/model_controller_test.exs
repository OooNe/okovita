defmodule OkovitaWeb.Transports.REST.Controllers.ModelControllerTest do
  use OkovitaWeb.ConnCase, async: false

  alias Okovita.Tenants

  @blog_schema %{
    "title" => %{"field_type" => "text", "label" => "Title", "required" => true},
    "body" => %{"field_type" => "textarea", "label" => "Body", "required" => true}
  }

  setup %{conn: conn} do
    {:ok, %{tenant: tenant, raw_api_key: api_key}} =
      Tenants.create_tenant(%{name: "Model API Test", slug: "model-api"})

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

    conn = put_req_header(conn, "x-api-key", api_key)
    %{conn: conn, prefix: prefix}
  end

  describe "POST /api/v1/models" do
    test "creates a model", %{conn: conn} do
      params = %{
        "slug" => "blog-post",
        "name" => "Blog Post",
        "schema_definition" => @blog_schema
      }

      conn = post(conn, "/api/v1/models", params)

      assert %{"data" => %{"slug" => "blog-post", "name" => "Blog Post"}} =
               json_response(conn, 201)
    end

    test "returns 422 for invalid schema_definition", %{conn: conn} do
      params = %{
        "slug" => "bad",
        "name" => "Bad",
        "schema_definition" => %{"field" => %{"label" => "X", "required" => false}}
      }

      conn = post(conn, "/api/v1/models", params)
      assert json_response(conn, 422)["error"]
    end
  end

  describe "GET /api/v1/models" do
    test "lists models", %{conn: conn} do
      # Create a model first
      post(conn, "/api/v1/models", %{
        "slug" => "pages",
        "name" => "Pages",
        "schema_definition" => @blog_schema
      })

      conn = get(conn, "/api/v1/models")
      assert %{"data" => models} = json_response(conn, 200)
      assert length(models) == 1
    end
  end

  describe "PUT /api/v1/models/:id" do
    test "updates a model", %{conn: conn} do
      resp =
        post(conn, "/api/v1/models", %{
          "slug" => "update-me",
          "name" => "Original",
          "schema_definition" => @blog_schema
        })

      model_id = json_response(resp, 201)["data"]["id"]
      conn = put(conn, "/api/v1/models/#{model_id}", %{"name" => "Updated"})
      assert %{"data" => %{"name" => "Updated"}} = json_response(conn, 200)
    end
  end
end
