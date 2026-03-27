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

  scope "/media", OkovitaWeb do
    pipe_through :browser

    get "/:bucket/:filename", MediaProxyController, :show
  end

  scope "/admin", OkovitaWeb.Admin do
    pipe_through [:browser]

    get "/session", SessionController, :create
    delete "/session", SessionController, :delete
  end

  scope "/admin", OkovitaWeb do
    pipe_through [:browser, :admin_auth]

    # Backup downloads
    get "/backups/download/:filename", BackupDownloadController, :download
  end

  scope "/admin", OkovitaWeb.Admin do
    pipe_through [:browser, :admin_auth]

    # Dashboard root — redirect to tenants
    get "/", SessionController, :dashboard

    # Super admin routes
    live_session :admin,
      layout: {OkovitaWeb.Layouts, :tenant},
      on_mount: [{OkovitaWeb.LiveAuth, :require_super_admin}] do
      live "/tenants", TenantLive.Index
    end

    # Tenant context routes (accessible by Super Admin and Tenant Admin)
    live_session :tenant,
      layout: {OkovitaWeb.Layouts, :tenant},
      on_mount: [
        {OkovitaWeb.LiveAuth, :require_tenant_admin},
        {OkovitaWeb.LiveAuth, :assign_tenant_layout_data}
      ] do
      scope "/tenants/:tenant_slug" do
        live "/api-keys", TenantLive.ApiKeys
        live "/backups", BackupLive.Index
        live "/media", MediaLive.Index
        live "/models", ContentLive.ModelList
        live "/models/new", ContentLive.ModelBuilder
        live "/models/:id/edit", ContentLive.ModelBuilder
        live "/models/:model_slug/entries", ContentLive.EntryList
        live "/models/:model_slug/entries/new", ContentLive.EntryForm
        live "/models/:model_slug/entries/:id/edit", ContentLive.EntryForm
        live "/models/:model_slug/entries/:id/history", ContentLive.EntryHistoryLive

        # Timeline
        live "/timeline/:entity_type/:entity_id", TimelineLive

        # OpenAPI integration
        live "/api-docs", ContentLive.ApiDocs
      end
    end

    scope "/tenants/:tenant_slug" do
      get "/openapi.json", OpenAPIController, :show
    end

    # Tenant-scoped CKEditor endpoints
    scope "/api/tenants/:tenant_slug" do
      post "/ckeditor/upload", CKEditorUploadController, :upload
    end
  end

  # ── Public API Docs ───────────────────────────────────────────────

  scope "/api/v1", OkovitaWeb.Transports.REST.Controllers do
    pipe_through [:browser]

    get "/tenants/:tenant_slug/docs", PublicDocsController, :show
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

    # Public OpenAPI spec per tenant — no API key required
    get "/tenants/:tenant_slug/openapi.json", PublicOpenAPIController, :show
  end

  # Tenant-scoped API — requires x-api-key header
  scope "/api/v1", OkovitaWeb.Transports.REST.Controllers do
    pipe_through :tenant_api

    # Content models
    get "/models", ModelController, :index
    get "/models/:id", ModelController, :show
    post "/models", ModelController, :create
    put "/models/:id", ModelController, :update
    delete "/models/:id", ModelController, :delete

    # Components
    get "/components/:slug", ComponentController, :show
    put "/components/:slug", ComponentController, :update

    # Content entries
    get "/models/:model_slug/entries", EntryController, :index
    get "/models/:model_slug/entries/by-slug/:slug", EntryController, :show_by_slug
    get "/models/:model_slug/entries/:id", EntryController, :show
    get "/models/:model_slug/entries/:id/:child_model_slug", EntryController, :relations
    post "/models/:model_slug/entries", EntryController, :create
    put "/models/:model_slug/entries/:id", EntryController, :update
    delete "/models/:model_slug/entries/:id", EntryController, :delete
  end
end
