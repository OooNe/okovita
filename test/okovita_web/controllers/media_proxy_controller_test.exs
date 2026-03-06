defmodule OkovitaWeb.MediaProxyControllerTest do
  use OkovitaWeb.ConnCase

  import Okovita.Factory
  alias Okovita.Content.Media

  setup do
    bypass = Bypass.open()

    slug = "test-tenant-#{System.unique_integer([:positive])}"

    Application.put_env(:ex_aws, :s3,
      scheme: "http://",
      host: "localhost",
      port: bypass.port
    )

    {:ok, %{tenant: tenant}} =
      Okovita.Tenants.create_tenant(%{name: "Test Tenant", slug: slug})

    on_exit(fn ->
      schema_name = Okovita.Tenants.tenant_prefix(tenant)
      Okovita.Repo.query("DROP SCHEMA \"#{schema_name}\" CASCADE")
    end)

    {:ok, bypass: bypass, tenant: tenant}
  end

  defp create_media(tenant, attributes) do
    # Using Ecto.Query to insert into tenant prefix
    %Media{}
    |> Media.changeset(attributes)
    |> Ecto.Changeset.put_change(:id, Ecto.UUID.generate())
    |> Okovita.Repo.insert!(prefix: Okovita.Tenants.tenant_prefix(tenant))
  end

  describe "GET /media/:bucket/:filename" do
    test "redirects to S3 when no processing parameters are present", %{
      conn: conn,
      bypass: bypass,
      tenant: tenant
    } do
      media =
        create_media(tenant, %{
          file_name: "test.jpg",
          url: "http://localhost:#{bypass.port}/test.jpg",
          mime_type: "image/jpeg",
          size: 1000
        })

      conn = get(conn, "/media/okovita-content/#{media.file_name}")
      assert redirected_to(conn, 302) =~ "okovita-content/#{media.file_name}"
    end

    test "returns 400 for invalid width", %{conn: conn, bypass: bypass, tenant: tenant} do
      media =
        create_media(tenant, %{
          file_name: "test.jpg",
          url: "http://localhost:#{bypass.port}/test.jpg",
          mime_type: "image/jpeg",
          size: 1000
        })

      conn = get(conn, "/media/okovita-content/#{media.file_name}?w=123")
      assert response(conn, 400) =~ "Invalid width"
    end

    test "returns 400 for invalid height", %{conn: conn, bypass: bypass, tenant: tenant} do
      media =
        create_media(tenant, %{
          file_name: "test.jpg",
          url: "http://localhost:#{bypass.port}/test.jpg",
          mime_type: "image/jpeg",
          size: 1000
        })

      conn = get(conn, "/media/okovita-content/#{media.file_name}?h=123")
      assert response(conn, 400) =~ "Invalid height"
    end

    test "downloads image from S3, processes it, and caches", %{
      conn: conn,
      bypass: bypass,
      tenant: tenant
    } do
      # Let's use a 1x1 base64 transparent gif as a base, or create a simple Image and write to memory.
      # Because Req expects a real image, we will generate a valid image.
      {:ok, img} = Image.new(100, 100, color: :red)
      {:ok, binary} = Image.write(img, :memory, suffix: ".jpg")

      Bypass.expect_once(bypass, "GET", "/okovita-content/test.jpg", fn conn ->
        Plug.Conn.resp(conn, 200, binary)
      end)

      media =
        create_media(tenant, %{
          file_name: "test.jpg",
          url: "http://localhost:#{bypass.port}/test.jpg",
          mime_type: "image/jpeg",
          size: byte_size(binary)
        })

      # Ensure cache dir is clean
      cache_dir = "priv/static/cache/media"
      File.rm_rf!(cache_dir)
      File.mkdir_p!(cache_dir)

      # 1. First request generates
      conn1 = get(conn, "/media/okovita-content/#{media.file_name}?w=100&q=80")
      assert response(conn1, 200)
      assert response_content_type(conn1, :webp)
      assert ["public, max-age=31536000"] = get_resp_header(conn1, "cache-control")

      # Find cache file
      {:ok, files} = File.ls(cache_dir)
      assert length(files) == 1
      cache_file = hd(files)

      # 2. Second request hits cache
      conn2 = get(conn, "/media/okovita-content/#{media.file_name}?w=100&q=80")
      assert response(conn2, 200)

      # Ensure it wasn't requested from Bypass again (Bypass.expect_once handles this)

      # Clean up
      File.rm_rf!(cache_dir)
    end
  end
end
