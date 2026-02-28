# Okovita

**Multi-Tenant Headless CMS** built with Elixir, Phoenix, and PostgreSQL.

## Features

- **Prefix-based multi-tenancy** — each tenant gets its own PostgreSQL schema (`tenant_{id}`)
- **Dynamic content models** — define content types with JSON schema definitions at runtime
- **Field type registry** — 13 built-in types, extensible via behaviour + vertical-slice structure
- **Media Library** — S3-backed file management with drag-and-drop upload, media picker, batch operations
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
│   │   ├── field_types/      # Type registry & vertical-slice implementations
│   │   │   ├── behaviour.ex        # Behaviour contract (primitive_type, cast, validate, editor_component?, configurator_component?)
│   │   │   ├── registry.ex         # Config-driven Agent registry, editor_for/1, configurator_for/1
│   │   │   ├── text/               # ← example vertical slice
│   │   │   │   ├── field_type.ex   # Okovita.FieldTypes.Text (cast, validate)
│   │   │   │   ├── editor.ex       # Okovita.FieldTypes.Text.Editor (Phoenix.Component UI for EntryForm)
│   │   │   │   └── configurator.ex # Okovita.FieldTypes.Text.Configurator (Phoenix.Component UI for ModelBuilder)
│   │   │   ├── image/
│   │   │   ├── image_gallery/
│   │   │   ├── relation_many/      # One-to-many relationship
│   │   │   └── rich_text/          # Stub — JS hook TBD
│   │   ├── content/          # Models, entries, media, dynamic changeset
│   │   │   ├── entry_data_normalizer.ex  # Centralizes media data coercion (mixed atom/string keys)
│   │   │   ├── media_queries.ex          # DB queries for Media records
│   │   │   └── media_uploads.ex          # S3 + DB orchestration, upload helpers
│   │   ├── media/
│   │   │   └── uploader.ex   # Raw S3 put/delete via ExAws
│   │   ├── pipeline/         # Sync data transforms
│   │   └── timeline/         # Audit log
│   └── okovita_web/          # Transport layer
│       ├── plugs/            # TenantPlug, AuthPlug
│       ├── transports/rest/  # REST controllers
│       ├── components/
│       │   ├── core_components.ex    # Generic inputs, buttons, labels
│       │   └── media_components.ex   # upload_toast, media_picker_modal
│       └── live/admin/       # LiveView dashboard
│           └── content_live/
│               ├── entry_form/
│               │   ├── save_handler.ex    # Data mutation & error handling
│               │   └── picker_handler.ex  # Media selection events
│               └── entry_form.ex     # Data-driven form — dispatches to editor components
├── priv/repo/migrations/
│   ├── public/               # Global schema migrations
│   └── tenant/               # Per-tenant migrations (includes media table)
└── test/
    └── okovita/content/
        └── entry_data_normalizer_test.exs
```

## Field Types

### Architecture: Vertical Slices

Each field type is a self-contained directory with up to three files:

```
lib/okovita/field_types/<type>/
  field_type.ex   ← backend: cast, validate (Okovita.FieldTypes.<Type>)
  editor.ex       ← frontend (EntryForm): Phoenix.Component render/1 (Okovita.FieldTypes.<Type>.Editor)
  configurator.ex ← frontend (ModelBuilder): Phoenix.Component render/1 (Okovita.FieldTypes.<Type>.Configurator) (Optional)
```

The **Registry** maps string names to modules, and resolves the editor component automatically by convention (`Module.Editor`):

```elixir
# config/config.exs
config :okovita, :field_types, %{
  "text"          => Okovita.FieldTypes.Text,
  "textarea"      => Okovita.FieldTypes.Textarea,
  "number"        => Okovita.FieldTypes.Number,
  "integer"       => Okovita.FieldTypes.Integer,
  "boolean"       => Okovita.FieldTypes.Boolean,
  "enum"          => Okovita.FieldTypes.Enum,
  "date"          => Okovita.FieldTypes.Date,
  "datetime"      => Okovita.FieldTypes.Datetime,
  "relation"      => Okovita.FieldTypes.Relation,
  "relation_many" => Okovita.FieldTypes.RelationMany,
  "image"         => Okovita.FieldTypes.Image,
  "image_gallery" => Okovita.FieldTypes.ImageGallery,
  "rich_text"     => Okovita.FieldTypes.RichText       # ← stub, JS hook TBD
}
```

### Adding a New Field Type

1. Create the directory and files:

   ```
   lib/okovita/field_types/my_type/
     field_type.ex
     editor.ex
     configurator.ex (optional)
   ```

2. Implement `Okovita.FieldTypes.Behaviour` in `field_type.ex`:

   ```elixir
   defmodule Okovita.FieldTypes.MyType do
     @behaviour Okovita.FieldTypes.Behaviour

     @impl true
     def primitive_type, do: :string   # Ecto type

     @impl true
     def cast(value), do: {:ok, value}

     @impl true
     def validate(changeset, _field, _opts), do: changeset
   end
   ```

3. Implement the editor component in `editor.ex`:

   ```elixir
   defmodule Okovita.FieldTypes.MyType.Editor do
     use Phoenix.Component

     attr :name, :string, required: true
     attr :value, :string, default: ""

     def render(assigns) do
       ~H"""
       <input type="text" name={@name} value={@value} />
       """
     end
   end
   ```

4. Register in `config/config.exs`:

   ```elixir
   config :okovita, :field_types, Map.put(existing_map, "my_type", Okovita.FieldTypes.MyType)
   ```

No changes to `EntryForm` or `ModelBuilder` required — the registry resolves `MyType.Editor` and `MyType.Configurator` automatically.

### Behaviour Reference

```elixir
@callback primitive_type() :: atom()
# e.g. :string | :integer | :float | :boolean | :date | :utc_datetime | :map | {:array, :map}

@callback cast(value :: any()) :: {:ok, any()} | :error

@callback validate(
  changeset :: Ecto.Changeset.t(),
  field_name :: atom(),
  options :: map()       # from schema_definition, e.g. %{"max_length" => 255, "one_of" => [...]}
) :: Ecto.Changeset.t()

# Optional — override editor_component/0 if you want an explicit module name for EntryForm:
@callback editor_component() :: module()

# Optional — override configurator_component/0 if you want an explicit module name for ModelBuilder:
@callback configurator_component() :: module()

# Optional — provide upload configuration for fields handling files (e.g. max_entries, max_file_size, accept):
@callback upload_config() :: keyword() | nil

# Optional — return additional assigns required by the editor component, computed from form/field context:
@callback form_assigns(form :: Phoenix.HTML.Form.t(), field :: atom(), options :: map()) :: map()

@optional_callbacks [editor_component: 0, configurator_component: 0, upload_config: 0, form_assigns: 3]
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
# Field types registry — string key → module
config :okovita, :field_types, %{
  "text" => Okovita.FieldTypes.Text,
  # ...
}

# Sync pipelines — applied to all string values before persistence
config :okovita, :sync_pipelines, trim: Okovita.Pipeline.Sync.Trim

# Active transports
config :okovita, :transports, [Okovita.Transports.REST]
```

## Media Library

The Media Library (`/admin/media`) provides per-tenant file management:

- **Drag & drop upload** — drop files anywhere on the page; uses LiveView's `phx-drop-target` with a full-screen overlay
- **Auto-upload** — files upload to S3 immediately after selection, no manual submit required
- **Media Picker** — modal for selecting existing media from the library, used by `image` and `image_gallery` fields
- **Batch selection & deletion** — select multiple items; confirm modal warns if any file is in use
- **S3 sync on delete** — deleting a media record also removes the object from S3

### Reusing upload logic in other LiveViews

```elixir
import OkovitaWeb.MediaComponents  # <.upload_toast />, <.media_picker_modal />
alias Okovita.Content.MediaUploads

# In handle_progress/3:
results = consume_uploaded_entries(socket, :images, fn %{path: path}, entry ->
  case MediaUploads.process_and_create(path, entry.client_name, entry.client_type, prefix) do
    {:ok, media} -> {:ok, {:ok, media.id}}
    {:error, _}  -> {:ok, {:error, "Błąd: #{entry.client_name}"}}
  end
end)

socket |> MediaUploads.apply_upload_results(results)
```

## Data Normalization

`Okovita.Content.EntryDataNormalizer` centralizes all media data coercion logic.

The system handles data coming from two directions with different key formats:
- **Database / `populate_media`** → atom-key maps: `%{id: "uuid", url: "https://..."}`
- **LiveView form params / media picker** → string-key maps: `%{"id" => "uuid", "url" => "https://..."}`

```elixir
alias Okovita.Content.EntryDataNormalizer

# Extract media ID regardless of key format
EntryDataNormalizer.extract_image_id(%{id: "uuid-123"})     # => "uuid-123"
EntryDataNormalizer.extract_image_id(%{"id" => "uuid-123"}) # => "uuid-123"
EntryDataNormalizer.extract_image_id("uuid-123")            # => "uuid-123"

# Normalize gallery list (handles legacy strings, mixed atom/string keys, re-indexing)
EntryDataNormalizer.normalize_gallery(["uuid-1", "uuid-2"])
# => [%{"media_id" => "uuid-1", "index" => 0}, %{"media_id" => "uuid-2", "index" => 1}]
```

## Extension Points

Okovita is designed for extensibility. The following can be added without modifying core:

- **Custom field types** → add a `<type>/` directory with `field_type.ex` + `editor.ex`, register in config
- **New transports** (GraphQL, gRPC) → implement `Okovita.Transport.Behaviour`
- **Custom pipelines** → implement `Okovita.Pipeline.Behaviour`
- **Publishing workflows** → field_type plugin or Oban scheduler

## License

Private — All rights reserved.
