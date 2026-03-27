defmodule OkovitaWeb.BackupDownloadController do
  use OkovitaWeb, :controller

  @backups_dir "backups"

  def download(conn, %{"filename" => filename}) do
    # Security: prevent path traversal
    if String.contains?(filename, "..") or String.contains?(filename, "/") do
      conn
      |> put_status(:forbidden)
      |> text("Invalid filename")
    else
      file_path = Path.join(@backups_dir, filename)

      if File.exists?(file_path) do
        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
        |> send_file(200, file_path)
      else
        conn
        |> put_status(:not_found)
        |> text("Backup file not found")
      end
    end
  end
end
