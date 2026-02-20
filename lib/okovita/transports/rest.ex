defmodule Okovita.Transports.REST do
  @moduledoc """
  REST transport implementation.

  Provides RESTful API route definitions for content models and entries.
  """
  @behaviour Okovita.Transport.Behaviour

  alias OkovitaWeb.Transports.REST.Controllers.{
    EntryController,
    ModelController,
    TenantController
  }

  @impl true
  def child_spec(_opts), do: nil

  @impl true
  def routes do
    [
      # Tenant management (super admin)
      %{method: :get, path: "/tenants", controller: TenantController, action: :index},
      %{method: :get, path: "/tenants/:id", controller: TenantController, action: :show},
      %{method: :post, path: "/tenants", controller: TenantController, action: :create},
      %{
        method: :put,
        path: "/tenants/:id/suspend",
        controller: TenantController,
        action: :suspend
      },
      %{method: :delete, path: "/tenants/:id", controller: TenantController, action: :delete},

      # Content models (tenant admin)
      %{method: :get, path: "/models", controller: ModelController, action: :index},
      %{method: :get, path: "/models/:id", controller: ModelController, action: :show},
      %{method: :post, path: "/models", controller: ModelController, action: :create},
      %{method: :put, path: "/models/:id", controller: ModelController, action: :update},

      # Content entries
      %{
        method: :get,
        path: "/models/:model_slug/entries",
        controller: EntryController,
        action: :index
      },
      %{
        method: :get,
        path: "/models/:model_slug/entries/:id",
        controller: EntryController,
        action: :show
      },
      %{
        method: :post,
        path: "/models/:model_slug/entries",
        controller: EntryController,
        action: :create
      },
      %{
        method: :put,
        path: "/models/:model_slug/entries/:id",
        controller: EntryController,
        action: :update
      },
      %{
        method: :delete,
        path: "/models/:model_slug/entries/:id",
        controller: EntryController,
        action: :delete
      },

      # OpenAPI
      %{
        method: :get,
        path: "/openapi.json",
        controller: OkovitaWeb.Transports.REST.Controllers.OpenAPIController,
        action: :show
      }
    ]
  end
end
