defmodule Mix.Tasks.Okovita.Backup.Import do
  use Mix.Task
  require Logger

  @shortdoc "Imports tenant data from a JSON backup file"

  @moduledoc """
  Imports tenant data from a backup file, replacing ALL existing data.

  ⚠️  WARNING: This operation will DELETE all existing models, entries,
  and media for the specified tenant before importing from the backup.

  ## Usage

      mix okovita.backup.import --file BACKUP_FILE --tenant TENANT_SLUG [options]

  ## Options

    * `--file` - (Required) Path to the backup JSON file
    * `--tenant` - (Required) The slug of the tenant to import into
    * `--dry-run` - Validate the backup file without making changes

  ## Examples

      # Dry run to validate backup
      mix okovita.backup.import --file backup.json --tenant my-tenant --dry-run

      # Import (will prompt for confirmation)
      mix okovita.backup.import --file backup.json --tenant my-tenant

  """

  @switches [
    file: :string,
    tenant: :string,
    dry_run: :boolean
  ]

  @aliases [
    f: :file,
    t: :tenant
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _remaining, invalid} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    if invalid != [] do
      Logger.error("Invalid options: #{inspect(invalid)}")
      print_usage()
      exit({:shutdown, 1})
    end

    with {:ok, file_path} <- get_required_opt(opts, :file, "backup file"),
         {:ok, tenant_slug} <- get_required_opt(opts, :tenant, "tenant slug") do
      dry_run = Keyword.get(opts, :dry_run, false)

      unless dry_run do
        confirm_destructive_operation(tenant_slug)
      end

      import_opts = [dry_run: dry_run]

      case Okovita.Backup.Importer.import_tenant(file_path, tenant_slug, import_opts) do
        {:ok, summary} ->
          if summary.dry_run do
            Logger.info("✓ Dry run validation successful")
            Logger.info("  - Models: #{summary.models_count}")
            Logger.info("  - Entries: #{summary.entries_count}")
            Logger.info("  - Media: #{summary.media_count}")
          else
            Logger.info("✓ Import completed successfully")
            Logger.info("  - Models imported: #{summary.models_count}")
            Logger.info("  - Entries imported: #{summary.entries_count}")
            Logger.info("  - Media imported: #{summary.media_count}")
          end

          :ok

        {:error, :tenant_not_found} ->
          Logger.error("✗ Tenant '#{tenant_slug}' not found")
          exit({:shutdown, 1})

        {:error, {:file_read, reason}} ->
          Logger.error("✗ Failed to read backup file: #{inspect(reason)}")
          exit({:shutdown, 1})

        {:error, {:json_decode, reason}} ->
          Logger.error("✗ Invalid JSON in backup file: #{inspect(reason)}")
          exit({:shutdown, 1})

        {:error, {:unsupported_version, version}} ->
          Logger.error("✗ Unsupported backup version: #{version}")
          Logger.error("  This tool supports version #{Okovita.Backup.Format.current_version()}")
          exit({:shutdown, 1})

        {:error, reason} ->
          Logger.error("✗ Import failed: #{inspect(reason)}")
          exit({:shutdown, 1})
      end
    else
      {:error, message} ->
        Logger.error("✗ #{message}")
        print_usage()
        exit({:shutdown, 1})
    end
  end

  defp get_required_opt(opts, key, name) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, "Missing required option: --#{key} (#{name})"}
    end
  end

  defp confirm_destructive_operation(tenant_slug) do
    Logger.warning("")
    Logger.warning("⚠️  WARNING: DESTRUCTIVE OPERATION")
    Logger.warning("⚠️  This will DELETE ALL existing data for tenant '#{tenant_slug}':")
    Logger.warning("   - All content models")
    Logger.warning("   - All content entries")
    Logger.warning("   - All media records")
    Logger.warning("")
    Logger.warning("This operation cannot be undone!")
    Logger.warning("")
    IO.write("Type 'yes' to continue or anything else to abort: ")

    case IO.gets("") |> String.trim() do
      "yes" ->
        Logger.info("Proceeding with import...")

      _ ->
        Logger.info("Import aborted by user")
        exit({:shutdown, 0})
    end
  end

  defp print_usage do
    IO.puts("""

    Usage: mix okovita.backup.import --file BACKUP_FILE --tenant TENANT_SLUG [options]

    Required:
      --file, -f      Path to backup JSON file
      --tenant, -t    Tenant slug to import into

    Options:
      --dry-run       Validate only, don't execute

    Examples:
      mix okovita.backup.import -f backup.json -t my-tenant --dry-run
      mix okovita.backup.import --file backup.json --tenant my-tenant
    """)
  end
end
