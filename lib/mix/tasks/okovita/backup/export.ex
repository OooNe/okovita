defmodule Mix.Tasks.Okovita.Backup.Export do
  use Mix.Task
  require Logger

  @shortdoc "Exports a tenant's data to a JSON backup file"

  @moduledoc """
  Exports a tenant's content (models, entries, media) to a JSON backup file.

  ## Usage

      mix okovita.backup.export --tenant TENANT_SLUG [--output OUTPUT_DIR] [--pretty]

  ## Options

    * `--tenant` - (Required) The slug of the tenant to export
    * `--output` - Output directory for the backup file (default: current directory)
    * `--pretty` - Pretty-print the JSON output for readability

  ## Examples

      # Export to current directory
      mix okovita.backup.export --tenant my-tenant

      # Export to specific directory with pretty formatting
      mix okovita.backup.export --tenant my-tenant --output ./backups --pretty

  """

  @switches [
    tenant: :string,
    output: :string,
    pretty: :boolean
  ]

  @aliases [
    t: :tenant,
    o: :output,
    p: :pretty
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

    case Keyword.fetch(opts, :tenant) do
      {:ok, tenant_slug} ->
        export_opts = [
          output_dir: Keyword.get(opts, :output, "."),
          pretty: Keyword.get(opts, :pretty, false)
        ]

        case Okovita.Backup.Exporter.export_tenant(tenant_slug, export_opts) do
          {:ok, file_path} ->
            Logger.info("✓ Backup saved: #{file_path}")
            :ok

          {:error, :tenant_not_found} ->
            Logger.error("✗ Tenant '#{tenant_slug}' not found")
            exit({:shutdown, 1})

          {:error, reason} ->
            Logger.error("✗ Export failed: #{inspect(reason)}")
            exit({:shutdown, 1})
        end

      :error ->
        Logger.error("✗ Missing required option: --tenant")
        print_usage()
        exit({:shutdown, 1})
    end
  end

  defp print_usage do
    IO.puts("""

    Usage: mix okovita.backup.export --tenant TENANT_SLUG [options]

    Required:
      --tenant, -t    Tenant slug to export

    Options:
      --output, -o    Output directory (default: current directory)
      --pretty, -p    Pretty-print JSON output

    Examples:
      mix okovita.backup.export --tenant my-tenant
      mix okovita.backup.export -t my-tenant -o ./backups -p
    """)
  end
end
