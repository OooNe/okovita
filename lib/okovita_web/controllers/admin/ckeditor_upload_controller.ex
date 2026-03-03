defmodule OkovitaWeb.Admin.CKEditorUploadController do
  use OkovitaWeb, :controller

  alias Okovita.Content

  @doc """
  Handles CKEditor 5 image uploads.
  Expects `file` parameter as a `Plug.Upload` struct and `tenant_slug` from the path.
  """
  def upload(conn, %{"tenant_slug" => slug, "file" => %Plug.Upload{} = upload}) do
    # Fetch the tenant prefix to scope the media record correctly
    case Okovita.Tenants.get_tenant_by_slug(slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Tenant not found."}})

      tenant ->
        prefix = Okovita.Tenants.tenant_prefix(tenant)

        case Content.process_and_create_media(
               upload.path,
               upload.filename,
               upload.content_type,
               prefix
             ) do
          {:ok, media} ->
            json(conn, %{url: media.url})

          {:error, _reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: %{message: "Failed to process and upload image."}})
        end
    end
  end

  def upload(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: %{message: "Invalid upload parameters."}})
  end
end
