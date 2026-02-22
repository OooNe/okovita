defmodule Okovita.Content.MediaUploads do
  @moduledoc """
  Handles higher-level media operations: orchestrating S3 uploads + DB record creation,
  plus shared helpers reused by every LiveView that exposes file upload capability.
  """

  import Phoenix.LiveView, only: [put_flash: 3]

  alias Okovita.Media.Uploader
  alias Okovita.Content

  @doc """
  Processes a raw uploaded temporary file, uploads it to S3, and creates a database record.

  Returns `{:ok, media}` or `{:error, reason}`.
  """
  def process_and_create(path, client_name, client_type, prefix) do
    with {:ok, attrs} <- Uploader.upload(path, client_name, client_type),
         {:ok, media} <- Content.create_media(attrs, prefix) do
      {:ok, media}
    else
      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "Failed to orchestrate upload and database creation for #{client_name}"}
    end
  end

  @doc """
  Applies flash messages to a LiveView socket based on a list of
  `{:ok, _} | {:error, message}` tuples returned by `consume_uploaded_entries/3`.

  Returns the updated socket (does NOT wrap in `{:noreply, socket}`).
  """
  def apply_upload_results(socket, []), do: socket

  def apply_upload_results(socket, results) do
    errors = for {:error, msg} <- results, do: msg

    if Enum.empty?(errors) do
      put_flash(socket, :info, "Media wgrane pomyślnie!")
    else
      put_flash(socket, :error, Enum.join(errors, " | "))
    end
  end

  @doc """
  Returns a human-readable Polish error label for a LiveView upload error atom.
  """
  def upload_error_label(:too_large), do: "Plik jest zbyt duży"
  def upload_error_label(:too_many_files), do: "Wybrałeś zbyt dużo plików"
  def upload_error_label(:not_accepted), do: "Wybrałeś niedozwolony typ pliku"
  def upload_error_label(_), do: "Nieznany błąd wgrywania"
end
