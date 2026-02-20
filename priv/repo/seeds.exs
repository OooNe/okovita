# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#

alias Okovita.Auth

# Create default super admin
case Auth.get_admin_by_email("admin@okovita.io") do
  nil ->
    {:ok, admin} =
      Auth.create_admin(%{
        email: "admin@okovita.io",
        password: "Admin123!",
        role: :super_admin
      })

    IO.puts("✅ Super admin created: #{admin.email}")

  _admin ->
    IO.puts("ℹ️  Super admin already exists: admin@okovita.io")
end
