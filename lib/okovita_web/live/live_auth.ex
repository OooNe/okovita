defmodule OkovitaWeb.LiveAuth do
  @moduledoc """
  LiveView on_mount hooks for role-based authentication.

  Use with `on_mount {OkovitaWeb.LiveAuth, :require_super_admin}` or
  `on_mount {OkovitaWeb.LiveAuth, :require_tenant_admin}` in LiveViews.
  """
  import Phoenix.LiveView
  import Phoenix.Component

  alias Okovita.Auth
  alias Okovita.Tenants

  def on_mount(:require_super_admin, _params, session, socket) do
    case load_admin(session) do
      %{role: :super_admin} = admin ->
        {:cont,
         socket
         |> assign(current_admin: admin)
         |> assign(
           current_tenant: %Okovita.Tenants.Tenant{
             id: nil,
             name: "SuperAdmin Global",
             slug: "system"
           }
         )
         |> assign(layout_tenants: Okovita.Tenants.list_tenants())
         |> assign(layout_models: [])}

      _ ->
        {:halt, redirect(socket, to: "/admin/login")}
    end
  end

  def on_mount(:require_tenant_admin, params, session, socket) do
    case load_admin(session) do
      # Tenant Admin: Must access their own tenant
      %{role: :tenant_admin, tenant_id: admin_tenant_id} = admin ->
        tenant = Tenants.get_tenant(admin_tenant_id)

        # If URL has tenant_slug, ensure it matches the admin's tenant
        slug_check =
          case params["tenant_slug"] do
            # Some legacy/direct routes might not have it yet
            nil -> :ok
            slug when slug == tenant.slug -> :ok
            _ -> :error
          end

        if tenant && slug_check == :ok do
          {:cont,
           socket
           |> assign(current_admin: admin)
           |> assign(current_tenant: tenant)
           |> assign(tenant_prefix: Tenants.tenant_prefix(tenant))}
        else
          {:halt, redirect(socket, to: "/admin/login")}
        end

      # Super Admin: Can access ANY tenant if slug is provided
      %{role: :super_admin} = admin ->
        case params["tenant_slug"] do
          nil ->
            # No tenant context — redirect to tenant list
            {:halt, redirect(socket, to: "/admin/tenants")}

          slug ->
            case Tenants.get_tenant_by_slug(slug) do
              nil ->
                {:halt,
                 socket
                 |> put_flash(:error, "Tenant not found")
                 |> redirect(to: "/admin/tenants")}

              tenant ->
                {:cont,
                 socket
                 |> assign(current_admin: admin)
                 |> assign(current_tenant: tenant)
                 |> assign(tenant_prefix: Tenants.tenant_prefix(tenant))}
            end
        end

      _ ->
        {:halt, redirect(socket, to: "/admin/login")}
    end
  end

  def on_mount(:require_any_admin, _params, session, socket) do
    case load_admin(session) do
      nil ->
        {:halt, redirect(socket, to: "/admin/login")}

      admin ->
        {:cont, assign(socket, current_admin: admin)}
    end
  end

  def on_mount(:assign_tenant_layout_data, params, _session, socket) do
    if socket.assigns[:current_admin] && socket.assigns[:current_tenant] do
      layout_tenants =
        if socket.assigns.current_admin.role == :super_admin do
          Okovita.Tenants.list_tenants()
        else
          [socket.assigns.current_tenant]
        end

      layout_models = Okovita.Content.list_models(socket.assigns.tenant_prefix)

      # Determine active navigation section based on route params
      active_nav =
        cond do
          params["id"] && String.contains?(socket.view |> to_string(), "ModelBuilder") ->
            "schema_#{params["id"]}"

          params["model_slug"] ->
            "entity_#{params["model_slug"]}"

          String.contains?(socket.view |> to_string(), "ApiDocs") ->
            :api_docs

          true ->
            if socket.assigns.current_tenant.id == nil, do: :global, else: :none
        end

      {:cont,
       assign(socket,
         layout_tenants: layout_tenants,
         layout_models: layout_models,
         active_nav: active_nav
       )}
    else
      {:cont, socket}
    end
  end

  defp load_admin(session) do
    case Map.get(session, "admin_id") do
      nil -> nil
      admin_id -> Auth.get_admin(admin_id)
    end
  end
end
