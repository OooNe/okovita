defmodule Mix.Tasks.Tenants.Migrate do
  use Mix.Task
  require Logger

  @shortdoc "Runs Okovita.Tenants.run_tenant_migrations/1 for all existing tenants"
  def run(_) do
    Mix.Task.run("app.start")

    tenants = Okovita.Repo.all(Okovita.Tenants.Tenant)
    Logger.info("Starting migrations for #{length(tenants)} tenants...")

    for tenant <- tenants do
      prefix = Okovita.Tenants.tenant_prefix(tenant)
      Logger.info("Migrating schema: #{prefix}")
      Okovita.Tenants.run_tenant_migrations(prefix)
    end

    Logger.info("Tenant migrations completed successfully.")
  end
end
