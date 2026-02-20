defmodule Okovita.Tenants do
  @moduledoc """
  Context for tenant management.

  Handles tenant lifecycle: creation (with schema provisioning),
  suspension, soft-deletion, and API key verification.
  """
  alias Okovita.Repo
  alias Okovita.Tenants.Tenant
  alias Okovita.Tenants.ApiKey

  @api_key_bytes 32

  @doc """
  Creates a new tenant with its own PostgreSQL schema.

  Generates a random API key, hashes it with bcrypt, and:
  1. Inserts the tenant record
  2. Creates a new PostgreSQL schema `tenant_{id}`
  3. Runs all tenant migrations in the new schema

  Returns `{:ok, %{tenant: tenant, raw_api_key: raw_key}}` on success.
  The raw API key is shown once and never stored.
  """
  @spec create_tenant(map()) ::
          {:ok, %{tenant: Tenant.t(), raw_api_key: String.t()}} | {:error, any()}
  def create_tenant(attrs) do
    changeset = Tenant.create_changeset(%Tenant{}, attrs)

    # Validate changeset before doing any DDL
    if changeset.valid? do
      case Repo.insert(changeset) do
        {:ok, tenant} ->
          prefix = tenant_prefix(tenant)

          # DDL operations — CREATE SCHEMA must run outside sandbox transaction
          # because schema creation is non-transactional in practice
          case create_tenant_schema(prefix) do
            :ok ->
              # Auto-provision a default API key
              {:ok, api_key_res} = create_api_key(tenant.id, "Default API Key")
              {:ok, %{tenant: tenant, raw_api_key: api_key_res.raw_api_key}}

            {:error, reason} ->
              # Clean up the tenant record if schema creation fails
              Repo.delete(tenant)
              {:error, {:create_schema, reason}}
          end

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, %{changeset | action: :insert}}
    end
  end

  defp create_tenant_schema(prefix) do
    case Repo.query("CREATE SCHEMA \"#{prefix}\"") do
      {:ok, _} ->
        run_tenant_migrations(prefix)
        :ok

      {:error, %Postgrex.Error{postgres: %{code: :duplicate_schema}}} ->
        # Schema already exists, just run pending migrations
        run_tenant_migrations(prefix)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Suspends a tenant by setting status to `:suspended`.
  """
  @spec suspend_tenant(binary()) :: {:ok, Tenant.t()} | {:error, any()}
  def suspend_tenant(tenant_id) do
    case Repo.get(Tenant, tenant_id) do
      nil ->
        {:error, :not_found}

      tenant ->
        tenant
        |> Tenant.status_changeset(%{status: :suspended})
        |> Repo.update()
    end
  end

  @doc """
  Soft-deletes a tenant by setting `deleted_at` and status to `:suspended`.
  Never drops the PostgreSQL schema.
  """
  @spec delete_tenant(binary()) :: {:ok, Tenant.t()} | {:error, any()}
  def delete_tenant(tenant_id) do
    case Repo.get(Tenant, tenant_id) do
      nil ->
        {:error, :not_found}

      tenant ->
        tenant
        |> Tenant.status_changeset(%{
          status: :suspended,
          deleted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        })
        |> Repo.update()
    end
  end

  @doc """
  Looks up a tenant by raw API key.

  Returns `{:ok, tenant}` if found and active,
  `{:error, :suspended}` if found but suspended,
  `{:error, :not_found}` if not found.
  """
  @spec get_tenant_by_api_key(String.t()) ::
          {:ok, Tenant.t()} | {:error, :not_found} | {:error, :suspended}
  def get_tenant_by_api_key(raw_key) when is_binary(raw_key) do
    token_hash = hash_api_key(raw_key)

    case Repo.get_by(ApiKey, token_hash: token_hash) |> Repo.preload(:tenant) do
      nil ->
        {:error, :not_found}

      %ApiKey{tenant: %Tenant{status: :suspended}} ->
        {:error, :suspended}

      %ApiKey{tenant: %Tenant{status: :active} = tenant} ->
        {:ok, tenant}

      %ApiKey{tenant: nil} ->
        # Data anomaly (key without tenant), acts as invalid
        {:error, :not_found}
    end
  end

  def get_tenant_by_api_key(_), do: {:error, :not_found}

  # ── API Keys Management ────────────────────────────────────────────────

  @doc "Lists all API keys for a tenant."
  def list_api_keys(tenant_id) do
    import Ecto.Query
    Repo.all(from k in ApiKey, where: k.tenant_id == ^tenant_id, order_by: [desc: k.inserted_at])
  end

  @doc """
  Generates a new API key for a tenant.
  Returns `{:ok, %{api_key: ApiKey.t(), raw_api_key: String.t()}}` on success.
  """
  def create_api_key(tenant_id, name) do
    raw_api_key = generate_api_key()
    token_hash = hash_api_key(raw_api_key)

    attrs = %{
      tenant_id: tenant_id,
      name: name,
      token_hash: token_hash
    }

    %ApiKey{}
    |> ApiKey.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, api_key} -> {:ok, %{api_key: api_key, raw_api_key: raw_api_key}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc "Deletes an API key."
  def delete_api_key(tenant_id, key_id) do
    import Ecto.Query

    query = from k in ApiKey, where: k.id == ^key_id and k.tenant_id == ^tenant_id

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      api_key ->
        Repo.delete(api_key)
    end
  end

  @doc "Gets a tenant by ID."
  def get_tenant(id), do: Repo.get(Tenant, id)

  @doc "Gets a tenant by slug."
  def get_tenant_by_slug(slug) do
    import Ecto.Query
    Repo.one(from t in Tenant, where: t.slug == ^slug and is_nil(t.deleted_at))
  end

  @doc "Lists all non-deleted tenants."
  def list_tenants do
    import Ecto.Query
    Repo.all(from t in Tenant, where: is_nil(t.deleted_at), order_by: [asc: t.name])
  end

  @doc """
  Runs tenant table creation for a given prefix.
  Executes DDL directly via SQL to avoid Ecto.Migrator's Task spawning,
  which is incompatible with Ecto.Adapters.SQL.Sandbox.
  """
  def run_tenant_migrations(prefix) do
    # Create content_models table
    Repo.query!("""
    CREATE TABLE IF NOT EXISTS "#{prefix}".content_models (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      slug varchar(255) NOT NULL,
      name varchar(255) NOT NULL,
      schema_definition jsonb NOT NULL DEFAULT '{}',
      inserted_at timestamp(0) WITHOUT TIME ZONE NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
      updated_at timestamp(0) WITHOUT TIME ZONE NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
    )
    """)

    Repo.query!("""
    CREATE UNIQUE INDEX IF NOT EXISTS content_models_slug_index
      ON "#{prefix}".content_models (slug)
    """)

    # Create content_entries table
    Repo.query!("""
    CREATE TABLE IF NOT EXISTS "#{prefix}".content_entries (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      slug varchar(255) NOT NULL,
      data jsonb NOT NULL DEFAULT '{}',
      model_id uuid NOT NULL REFERENCES "#{prefix}".content_models(id) ON DELETE RESTRICT,
      inserted_at timestamp(0) WITHOUT TIME ZONE NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
      updated_at timestamp(0) WITHOUT TIME ZONE NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
    )
    """)

    Repo.query!("""
    CREATE UNIQUE INDEX IF NOT EXISTS content_entries_model_id_slug_index
      ON "#{prefix}".content_entries (model_id, slug)
    """)

    Repo.query!("""
    CREATE INDEX IF NOT EXISTS content_entries_model_id_index
      ON "#{prefix}".content_entries (model_id)
    """)

    # Create timeline table
    Repo.query!("""
    CREATE TABLE IF NOT EXISTS "#{prefix}".timeline (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      entity_id uuid NOT NULL,
      entity_type varchar(255) NOT NULL,
      action varchar(255) NOT NULL,
      actor_id uuid,
      before jsonb,
      after jsonb,
      inserted_at timestamp(0) WITHOUT TIME ZONE NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
    )
    """)

    Repo.query!("""
    CREATE INDEX IF NOT EXISTS timeline_entity_id_entity_type_index
      ON "#{prefix}".timeline (entity_id, entity_type)
    """)

    Repo.query!("""
    CREATE INDEX IF NOT EXISTS timeline_inserted_at_index
      ON "#{prefix}".timeline (inserted_at)
    """)

    :ok
  end

  @doc "Returns the tenant prefix string for a given tenant."
  def tenant_prefix(%Tenant{id: id}), do: "tenant_#{id}"
  def tenant_prefix(id) when is_binary(id), do: "tenant_#{id}"

  defp generate_api_key do
    @api_key_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp hash_api_key(raw_key) when is_binary(raw_key) do
    :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower)
  end
end
