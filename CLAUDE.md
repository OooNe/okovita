# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Okovita

A multi-tenant headless CMS built with Elixir/Phoenix. Each tenant defines custom content models at runtime with a pluggable field type system, media management via S3, REST API, audit trails, and a LiveView admin UI.

## Commands

```bash
# Development
mix setup            # Full initial setup (deps, ecto, assets)
mix phx.server       # Start dev server

# Testing
mix test                                    # Full test suite
mix test test/path/to/file_test.exs        # Single test file
mix test --failed                           # Re-run previously failed tests

# Code quality (run before committing)
mix precommit        # compile (warnings-as-errors) + format + test

# Assets
mix assets.build     # Build CSS + JS
mix assets.deploy    # Minify for production

# Database
mix ecto.reset       # Drop + recreate + migrate
mix ecto.gen.migration migration_name_using_underscores  # Always use this to generate migrations
```

**Do NOT run `mix compile` or `mix test` after every change** — only when diagnosing a specific error or when asked.

Docker-based equivalents exist in the `Makefile` (`make up`, `make test`, `make test-file FILE=...`).

## Architecture

### Multi-Tenancy

Each tenant gets its own PostgreSQL schema: `tenant_{uuid}`. The public schema holds global data (Tenants, Admins, APIKeys). All tenant-scoped operations require passing a `prefix` string. Tenant migrations live in `priv/repo/tenant/` and are run per-tenant on creation. `TenantPlug` validates `x-api-key` headers and populates `assigns.tenant_prefix`.

### Field Type Plugin System

The core extensibility mechanism. Each field type is a directory under `lib/okovita/field_types/{type}/` implementing `Okovita.FieldTypes.Behaviour`:

- **`field_type.ex`** — implements `primitive_type/0`, `cast/1`, `validate/3`, and optionally `form_assigns/3`, `merge_validate_params/3`, `default_value/0`, `upload_config/0`
- **`editor.ex`** — Phoenix.Component rendered in entry forms
- **`configurator.ex`** — optional Phoenix.Component rendered in model builder (4th column)
- **`serializer.ex`** / **`populator.ex`** — optional, for API formatting and lazy-loading relations/media

Use `Okovita.FieldTypes.Base` macro to avoid boilerplate. Register new types in `config/config.exs` under `:field_types`. The registry (`Okovita.FieldTypes.Registry`) is an Agent started at boot.

**Field data storage:** All entry field values go into a single `data` map column (JSON) on `content_entries`. Schema validation uses schemaless Ecto changesets built at runtime from the model's `schema_definition` JSON.

### Content Model System

`content_models.schema_definition` is a JSON map: `%{"field_key" => %{"field_type" => "text", "label" => "...", "required" => true, "position" => 0, ...}}`. The model builder LiveView persists only keys listed in `@persisted_field_keys`. `DynamicChangeset` validates entry data at runtime against this definition.

### LiveView Admin

Located in `lib/okovita_web/live/admin/`. Two roles:
- **Super admin**: Tenant management (`/admin/tenants/...`)
- **Tenant admin**: Content management (`/admin/tenants/:slug/models`, `/admin/tenants/:slug/entries`, etc.)

LiveView templates **must** begin with `<Layouts.app flash={@flash} current_scope={:admin}>`. Routes use `live_session` blocks with `on_mount` hooks for auth. Never move routes outside their proper `live_session` — this causes `current_scope` errors.

`EntryForm` is data-driven: it reads `schema_definition` and dispatches rendering to each field type's `editor_component`. Save/picker logic is split into `entry_form/save_handler.ex` and `entry_form/picker_handler.ex`.

### Transport Layer

`Okovita.Transport.Behaviour` defines `child_spec/0` and `routes/0`. The only current implementation is `Okovita.Transports.REST`. Configured in `config/config.exs` under `:transports`.

### Media Library

Three-layer architecture — **always respect boundaries**:

| Layer | Module | Responsibility |
|---|---|---|
| Storage | `Okovita.Media.Uploader` | Raw S3 ops only, no DB |
| Domain | `Okovita.Content.MediaUploads` | Orchestrates upload → DB record |
| Query | `Okovita.Content.MediaQueries` | Ecto CRUD for Media records |
| Context | `Okovita.Content` | Public facade via `defdelegate` only |

Never call `Uploader` directly from a LiveView. Always call `MediaUploads.apply_upload_results/2` for upload flash messages. `allow_upload` must use `auto_upload: true` and `progress: &handle_progress/3`.

### Timeline / Audit Trail

Every mutation (create, update, delete, restore) is recorded in `timeline` via `Timeline.insert_audit/7` inside `Ecto.Multi` callbacks. Stores before/after JSON snapshots with actor info.

### Sync Pipelines

Run on all string values before entry persistence. Configured in `config/config.exs` under `:sync_pipelines`. Example: `Okovita.Pipeline.Sync.Trim`.

## Phoenix / Elixir Rules

- Use `<.icon name="hero-x-mark" />` for icons — never `Heroicons` modules
- Use `<.input>` from `core_components.ex` for form inputs — overriding `class` replaces all defaults
- Never call `<.flash_group>` outside `layouts.ex`
- Use `Req` for HTTP requests — not `:httpoison`, `:tesla`, or `:httpc`
- Never use map access syntax (`struct[:field]`) on Ecto structs — use `struct.field` or `Ecto.Changeset.get_field/2`
- Never nest multiple modules in the same file
- Don't use `String.to_atom/1` on user input
- Use `start_supervised!/1` in tests; avoid `Process.sleep/1`
- Test scripts go in `.agent_tests/` (git-ignored), not the project root
