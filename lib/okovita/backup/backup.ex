defmodule Okovita.Backup do
  @moduledoc """
  Public API for tenant backup and restore operations.

  This context provides functions to export tenant data to JSON backups
  and restore from those backups.

  ## Usage

  ### Export

      Okovita.Backup.export_tenant("my-tenant", output_dir: "./backups", pretty: true)
      # => {:ok, "backups/backup_my-tenant_2026-03-21T10-30-00Z.json"}

  ### Import

      Okovita.Backup.import_tenant("backup.json", "my-tenant")
      # => {:ok, %{models_count: 5, entries_count: 120, media_count: 45}}

      # Dry run validation
      Okovita.Backup.import_tenant("backup.json", "my-tenant", dry_run: true)
  """

  alias Okovita.Backup.{Exporter, Importer}

  @doc """
  Exports a tenant's data to a JSON backup file.

  ## Options
    * `:output_dir` - Directory to write the backup file (default: ".")
    * `:pretty` - Pretty-print JSON (default: false)

  ## Examples

      iex> Okovita.Backup.export_tenant("my-tenant")
      {:ok, "./backup_my-tenant_2026-03-21T10-30-00Z.json"}

      iex> Okovita.Backup.export_tenant("my-tenant", output_dir: "./backups", pretty: true)
      {:ok, "./backups/backup_my-tenant_2026-03-21T10-30-00Z.json"}

  """
  defdelegate export_tenant(tenant_slug, opts \\ []), to: Exporter

  @doc """
  Imports tenant data from a backup file.

  ⚠️  WARNING: This operation DELETES all existing data for the tenant
  before importing from the backup.

  ## Options
    * `:dry_run` - Validate only, don't execute (default: false)

  ## Examples

      iex> Okovita.Backup.import_tenant("backup.json", "my-tenant")
      {:ok, %{models_count: 5, entries_count: 120, media_count: 45}}

      iex> Okovita.Backup.import_tenant("backup.json", "my-tenant", dry_run: true)
      {:ok, %{models_count: 5, entries_count: 120, media_count: 45, dry_run: true}}

  """
  defdelegate import_tenant(file_path, tenant_slug, opts \\ []), to: Importer
end
