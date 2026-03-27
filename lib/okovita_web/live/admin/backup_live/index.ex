defmodule OkovitaWeb.Admin.BackupLive.Index do
  @moduledoc "LiveView for managing tenant backups (export/import)."
  use OkovitaWeb, :live_view

  alias Okovita.Backup

  @backups_dir "backups"

  def mount(_params, _session, socket) do
    # current_tenant is set by live_session :tenant hooks
    tenant = socket.assigns.current_tenant

    ensure_backups_dir()
    backups = list_backups(tenant.slug)

    {:ok,
     socket
     |> assign(
       backups: backups,
       exporting: false,
       importing: false,
       pending_import: nil
     )
     |> assign(:active_nav, "backups")
     |> allow_upload(:backup_file,
       accept: ~w(.json),
       max_entries: 1,
       max_file_size: 100_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  def handle_event("validate-upload", _params, socket), do: {:noreply, socket}

  # Export backup
  def handle_event("export-backup", _params, socket) do
    tenant = socket.assigns.current_tenant

    # Start async export task
    task =
      Task.async(fn ->
        Backup.export_tenant(tenant.slug, output_dir: @backups_dir, pretty: true)
      end)

    {:noreply,
     socket
     |> assign(exporting: true, export_task: task)
     |> put_flash(:info, "Exporting backup... This may take a moment.")}
  end

  def handle_event("confirm-import", _params, socket) do
    case socket.assigns[:pending_import] do
      %{file: file_path, summary: _summary} ->
        tenant = socket.assigns.current_tenant

        case Backup.import_tenant(file_path, tenant.slug) do
          {:ok, summary} ->
            File.rm(file_path)

            {:noreply,
             socket
             |> put_flash(
               :info,
               "Import completed! Imported #{summary.models_count} models, #{summary.entries_count} entries, #{summary.media_count} media."
             )
             |> push_navigate(to: "/admin/tenants/#{tenant.slug}/backups")}

          {:error, reason} ->
            File.rm(file_path)

            {:noreply,
             socket
             |> assign(pending_import: nil)
             |> put_flash(:error, "Import failed: #{inspect(reason)}")}
        end

      nil ->
        {:noreply, put_flash(socket, :error, "No pending import")}
    end
  end

  def handle_event("cancel-import", _params, socket) do
    case socket.assigns[:pending_import] do
      %{file: file_path} -> File.rm(file_path)
      nil -> :ok
    end

    {:noreply, assign(socket, pending_import: nil)}
  end

  # Download backup
  def handle_event("download-" <> filename, _params, socket) do
    file_path = Path.join(@backups_dir, filename)

    if File.exists?(file_path) do
      {:noreply,
       socket
       |> push_event("download", %{url: "/admin/backups/download/#{filename}"})}
    else
      {:noreply, put_flash(socket, :error, "Backup file not found")}
    end
  end

  # Delete backup
  def handle_event("delete-" <> filename, _params, socket) do
    file_path = Path.join(@backups_dir, filename)

    case File.rm(file_path) do
      :ok ->
        backups = list_backups(socket.assigns.current_tenant.slug)

        {:noreply,
         socket
         |> assign(backups: backups)
         |> put_flash(:info, "Backup deleted")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete backup")}
    end
  end

  # Upload progress handler
  def handle_progress(:backup_file, entry, socket) do
    if entry.done? do
      tenant = socket.assigns.current_tenant

      uploaded_files =
        consume_uploaded_entries(socket, :backup_file, fn %{path: path}, _entry ->
          # Copy to temp file for processing
          dest = Path.join(System.tmp_dir!(), "backup_import_#{:rand.uniform(999_999)}.json")
          File.cp!(path, dest)
          {:ok, dest}
        end)

      case uploaded_files do
        [file_path | _] ->
          # Automatically validate backup (dry-run)
          case Backup.import_tenant(file_path, tenant.slug, dry_run: true) do
            {:ok, summary} ->
              {:noreply,
               socket
               |> assign(importing: false, pending_import: %{file: file_path, summary: summary})
               |> put_flash(
                 :info,
                 "Backup validated successfully! Ready to import."
               )}

            {:error, reason} ->
              File.rm(file_path)

              {:noreply,
               socket
               |> assign(importing: false)
               |> put_flash(:error, "Backup validation failed: #{inspect(reason)}")}
          end

        [] ->
          {:noreply, assign(socket, importing: false)}
      end
    else
      # Upload in progress
      {:noreply, assign(socket, importing: true)}
    end
  end

  # Handle async task completion
  def handle_info({ref, result}, socket) do
    # Check if this is our export task
    if Map.has_key?(socket.assigns, :export_task) do
      Process.demonitor(ref, [:flush])

      case result do
        {:ok, file_path} ->
          backups = list_backups(socket.assigns.current_tenant.slug)

          {:noreply,
           socket
           |> assign(exporting: false, backups: backups)
           |> put_flash(:info, "Backup created successfully: #{Path.basename(file_path)}")}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(exporting: false)
           |> put_flash(:error, "Export failed: #{inspect(reason)}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, assign(socket, exporting: false)}
  end

  # Private helpers

  defp ensure_backups_dir do
    File.mkdir_p!(@backups_dir)
  end

  defp list_backups(tenant_slug) do
    pattern = Path.join(@backups_dir, "backup_#{tenant_slug}_*.json")

    Path.wildcard(pattern)
    |> Enum.map(&parse_backup_file/1)
    |> Enum.sort_by(& &1.created_at, {:desc, DateTime})
  end

  defp parse_backup_file(path) do
    filename = Path.basename(path)
    stat = File.stat!(path)

    # Try to extract timestamp from filename
    # Format: backup_tenant_2026-03-21T10-30-00Z.json
    created_at =
      case Regex.run(~r/backup_.*_(\d{4}-\d{2}-\d{2})T([\d-]+)(Z?)\.json/, filename) do
        [_, date_part, time_part, tz] ->
          # Convert time part: "10-30-00" -> "10:30:00"
          iso_time = String.replace(time_part, "-", ":")
          iso_timestamp = "#{date_part}T#{iso_time}#{tz}"

          case DateTime.from_iso8601(iso_timestamp) do
            {:ok, dt, _} -> dt
            _ -> fallback_datetime(stat.mtime)
          end

        _ ->
          fallback_datetime(stat.mtime)
      end

    %{
      filename: filename,
      path: path,
      size: stat.size,
      created_at: created_at
    }
  end

  defp fallback_datetime(mtime) do
    # mtime from File.stat! is an Erlang time tuple {{year, month, day}, {hour, minute, second}}
    # not a Unix timestamp!
    case NaiveDateTime.from_erl(mtime) do
      {:ok, naive_dt} ->
        DateTime.from_naive!(naive_dt, "Etc/UTC")

      {:error, _} ->
        DateTime.utc_now()
    end
  end

  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_size(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / 1024 / 1024, 1)} MB"

  defp format_size(bytes), do: "#{Float.round(bytes / 1024 / 1024 / 1024, 1)} GB"

  defp format_datetime(dt) do
    "#{dt.year}-#{pad(dt.month)}-#{pad(dt.day)} #{pad(dt.hour)}:#{pad(dt.minute)}:#{pad(dt.second)}"
  end

  defp pad(num) when num < 10, do: "0#{num}"
  defp pad(num), do: to_string(num)

  # Render

  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto py-8 px-4 sm:px-6 lg:px-8 space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Backups</h1>
        <p class="mt-2 text-sm text-gray-500">
          Export and import tenant data for disaster recovery or migration.
        </p>
      </div>

      <%!-- Pending import confirmation --%>
      <%= if @pending_import do %>
        <div class="rounded-md bg-yellow-50 p-4 border border-yellow-400">
          <div class="flex">
            <div class="flex-shrink-0">
              <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-yellow-400" />
            </div>
            <div class="ml-3 flex-1">
              <h3 class="text-sm font-medium text-yellow-800">Confirm Destructive Import</h3>
              <div class="mt-2 text-sm text-yellow-700">
                <p class="mb-2">
                  This will <strong>DELETE ALL existing data</strong>
                  for this tenant and replace it with the backup contents:
                </p>
                <ul class="list-disc list-inside space-y-1">
                  <li>Models: <%= @pending_import.summary.models_count %></li>
                  <li>Entries: <%= @pending_import.summary.entries_count %></li>
                  <li>Media: <%= @pending_import.summary.media_count %></li>
                </ul>
                <p class="mt-3 font-semibold">This action cannot be undone!</p>
              </div>
              <div class="mt-4 flex gap-3">
                <button
                  phx-click="confirm-import"
                  class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                >
                  Confirm Import
                </button>
                <button
                  phx-click="cancel-import"
                  class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Actions --%>
      <div class="flex gap-3">
        <button
          phx-click="export-backup"
          disabled={@exporting}
          class="inline-flex items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <%= if @exporting do %>
            <.icon name="hero-arrow-path" class="animate-spin h-4 w-4 mr-2" />
            Exporting...
          <% else %>
            <.icon name="hero-arrow-down-tray" class="h-4 w-4 mr-2" />
            Export Backup
          <% end %>
        </button>

        <form phx-change="validate-upload">
          <label class="inline-flex items-center justify-center rounded-md bg-green-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-green-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-green-600 transition-colors cursor-pointer">
            <%= if @importing do %>
              <.icon name="hero-arrow-path" class="animate-spin h-4 w-4 mr-2" />
              Validating...
            <% else %>
              <.icon name="hero-arrow-up-tray" class="h-4 w-4 mr-2" />
              Import Backup
            <% end %>
            <.live_file_input upload={@uploads.backup_file} class="hidden" />
          </label>
        </form>
      </div>

      <%!-- Backups list --%>
      <div class="overflow-hidden bg-white ring-1 ring-gray-200 shadow-sm sm:rounded-lg">
        <div class="px-4 py-5 sm:px-6 border-b border-gray-200 bg-gray-50">
          <h3 class="text-base font-semibold leading-6 text-gray-900">Existing Backups</h3>
          <p class="mt-1 text-sm text-gray-500">
            Backups are stored locally in the <code class="text-xs bg-gray-100 px-1 py-0.5 rounded">backups/</code>
            directory.
          </p>
        </div>

        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th
                scope="col"
                class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6"
              >
                Filename
              </th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                Created At (UTC)
              </th>
              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                Size
              </th>
              <th
                scope="col"
                class="relative py-3.5 pl-3 pr-4 sm:pr-6 text-right text-sm font-semibold text-gray-900"
              >
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 bg-white">
            <%= if length(@backups) == 0 do %>
              <tr>
                <td
                  colspan="4"
                  class="whitespace-nowrap py-8 pl-4 pr-3 text-sm text-center text-gray-500 italic sm:pl-6"
                >
                  No backups found. Create your first backup using the "Export Backup" button.
                </td>
              </tr>
            <% else %>
              <%= for backup <- @backups do %>
                <tr class="hover:bg-gray-50 transition-colors group">
                  <td class="py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                    <code class="text-xs bg-gray-100 px-2 py-1 rounded"><%= backup.filename %></code>
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500 font-mono">
                    <%= format_datetime(backup.created_at) %>
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                    <%= format_size(backup.size) %>
                  </td>
                  <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                    <div class="flex gap-3 justify-end">
                      <a
                        href={"/admin/backups/download/#{backup.filename}"}
                        download
                        class="text-indigo-600 hover:text-indigo-900 transition-colors"
                      >
                        Download
                      </a>
                      <button
                        phx-click={"delete-#{backup.filename}"}
                        data-confirm="Are you sure? This will permanently delete this backup file."
                        class="text-red-500 hover:text-red-700 transition-colors focus:outline-none"
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
