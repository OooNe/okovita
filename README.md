# Okovita

**Multi-Tenant Headless CMS** built with Elixir, Phoenix, and PostgreSQL.

## Features

- **Prefix-based multi-tenancy** — each tenant gets its own PostgreSQL schema (`tenant_{id}`)
- **Dynamic content models** — define content types with JSON schema definitions at runtime
- **Field type registry** — 8 built-in types (text, textarea, number, integer, boolean, enum, date, datetime), extensible via behaviour
- **Sync & async pipelines** — data transforms (trim, slugify) before storage, with Oban-powered async workers
- **Config-driven transport layer** — REST by default, extensible to GraphQL/gRPC without code changes
- **Full audit trail** — every content mutation logged in a timeline table
- **LiveView admin dashboard** — super admin (tenant management) + tenant admin (content management)
- **API key authentication** — per-tenant API keys with bcrypt hashing

## Tech Stack

| Component | Version |
|---|---|
| Elixir | 1.16+ |
| Phoenix | 1.7+ (LiveView, Ecto) |
| PostgreSQL | 15+ |
| Oban | 2.17+ |
| bcrypt_elixir | 3.0+ |

## Quick Start

### Prerequisites

- Docker & Docker Compose
- (Optional) Elixir 1.16+ & Erlang/OTP 26+ for local development

### First Run

```bash
make setup
make up
```

This will:
1. Copy `.env.example` → `.env`
2. Build the Docker image
3. Start PostgreSQL + LocalStack + Phoenix app
4. Create the database and run public migrations

### Daily Development

```bash
make up-d          # Start services in background
make iex           # Interactive Elixir shell
make logs          # Follow app logs
make check         # Run lint + tests before pushing
```

### Working with Tenants

```bash
make tenant-create NAME="Acme Corp" SLUG="acme"
make tenant-list
make tenant-migrate TENANT_ID=<uuid>
```

### Running Tests

```bash
make test                                              # Full test suite
make test-file FILE=test/okovita/tenants_test.exs      # Single file
make test-cover                                        # With coverage report
```

### All Available Commands

```bash
make help
```

## Project Structure

```
okovita/
├── lib/
│   ├── okovita/              # Business logic (contexts)
│   │   ├── tenants/          # Tenant management
│   │   ├── auth/             # Admin authentication
│   │   ├── field_types/      # Type registry & implementations
│   │   ├── content/          # Models, entries, dynamic changeset
│   │   ├── pipeline/         # Sync data transforms
│   │   └── timeline/         # Audit log
│   └── okovita_web/          # Transport layer
│       ├── plugs/            # TenantPlug, AuthPlug
│       ├── transports/rest/  # REST controllers
│       └── live/admin/       # LiveView dashboard
├── priv/repo/migrations/
│   ├── public/               # Global schema migrations
│   └── tenant/               # Per-tenant migrations
└── test/
```

## API Usage

All content API endpoints require an `x-api-key` header:

```bash
# Create an entry
curl -X POST http://localhost:4000/api/v1/entries/blog_post \
  -H "x-api-key: <your-api-key>" \
  -H "Content-Type: application/json" \
  -d '{"title": "Hello World", "body": "..."}'

# List entries
curl http://localhost:4000/api/v1/entries/blog_post \
  -H "x-api-key: <your-api-key>"
```

Response format:
```json
{
  "data": { ... },
  "meta": { "model": "blog_post", "tenant": "acme" },
  "errors": null
}
```

## Configuration

Key configuration in `config/config.exs`:

```elixir
# Field types (extensible)
config :okovita, :field_types, [
  Okovita.FieldTypes.Text,
  Okovita.FieldTypes.Textarea,
  # ...
]

# Sync pipelines
config :okovita, :sync_pipelines, [
  trim: Okovita.Pipeline.Sync.Trim,
  slugify: Okovita.Pipeline.Sync.Slugify
]

# Active transports
config :okovita, :transports, [
  Okovita.Transports.REST
]
```

## Extension Points

Okovita is designed for extensibility. The following can be added without modifying core:

- **Custom field types** → implement `Okovita.FieldTypes.Behaviour`
- **New transports** (GraphQL, gRPC) → implement `Okovita.Transport.Behaviour`
- **Custom pipelines** → implement `Okovita.Pipeline.Behaviour`
- **Publishing workflows** → field_type plugin or Oban scheduler
- **Asset management** → separate `Okovita.Assets` context with S3

## License

Private — All rights reserved.
