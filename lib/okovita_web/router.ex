defmodule OkovitaWeb.Router do
  use OkovitaWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :tenant_api do
    plug :accepts, ["json"]
    plug OkovitaWeb.Plugs.TenantPlug
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OkovitaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :admin_auth do
    plug OkovitaWeb.Plugs.AuthPlug
  end

  # ── Admin Dashboard ───────────────────────────────────────────────

  scope "/admin", OkovitaWeb.Admin do
    pipe_through :browser

    live "/login", LoginLive
  end

  scope "/admin", OkovitaWeb.Admin do
    pipe_through [:browser]

    get "/session", SessionController, :create
    delete "/session", SessionController, :delete
  end

  scope "/admin", OkovitaWeb.Admin do
    pipe_through [:browser, :admin_auth]

    # Dashboard root — redirect to tenants
    get "/", SessionController, :dashboard

    # Super admin routes
    live "/tenants", TenantLive.Index

    # Tenant context routes (accessible by Super Admin and Tenant Admin)
    scope "/tenants/:tenant_slug" do
      live "/api-keys", TenantLive.ApiKeys
      live "/models", ContentLive.ModelList
      live "/models/new", ContentLive.ModelBuilder
      live "/models/:id/edit", ContentLive.ModelBuilder
      live "/models/:model_slug/entries", ContentLive.EntryList
      live "/models/:model_slug/entries/new", ContentLive.EntryForm
      live "/models/:model_slug/entries/:id/edit", ContentLive.EntryForm

      # Timeline
      live "/timeline/:entity_type/:entity_id", TimelineLive

      # OpenAPI integration
      get "/openapi.json", OpenAPIController, :show
      live "/api-docs", ContentLive.ApiDocs
    end
  end

  # ── REST API ──────────────────────────────────────────────────────

  # Super admin API — no tenant plug required
  scope "/api/v1", OkovitaWeb.Transports.REST.Controllers do
    pipe_through :api

    get "/tenants", TenantController, :index
    get "/tenants/:id", TenantController, :show
    post "/tenants", TenantController, :create
    put "/tenants/:id/suspend", TenantController, :suspend
    delete "/tenants/:id", TenantController, :delete
  end

  # Tenant-scoped API — requires x-api-key header
  scope "/api/v1", OkovitaWeb.Transports.REST.Controllers do
    pipe_through :tenant_api

    # Content models
    get "/models", ModelController, :index
    get "/models/:id", ModelController, :show
    post "/models", ModelController, :create
    put "/models/:id", ModelController, :update

    # Content entries
    get "/models/:model_slug/entries", EntryController, :index
    get "/models/:model_slug/entries/:id", EntryController, :show
    post "/models/:model_slug/entries", EntryController, :create
    put "/models/:model_slug/entries/:id", EntryController, :update
    delete "/models/:model_slug/entries/:id", EntryController, :delete
  end
end
