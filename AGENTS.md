# AGENTS.md

Rails 8.1 monolith (PostgreSQL, Hotwire, Bootstrap 5, SolidQueue). No Redis.

## Data model overview

- **User** — authentication & admin powers only (Devise, OAuth). Has `admin` and `architect` boolean flags. No personal info.
- **Person** — real human record with all personal info (name, address, phone, bio, birthday, dietary restrictions, etc.). Optionally belongs to a User (`user_id` nullable). This is the hub most features connect to (memberships, badges, checkins, time punches, ledgers, relationships).
- **Team** — hierarchical tree of organizational units (typed via `TeamType`). People join teams through `Membership` (with a `manager` flag). Teams own events, pages, announcements, badges, time clock periods, ledgers, shortcuts, and calendar notes. Permissions cascade up and down the tree.
- **Finance** — `Ledger` per team, entries & transfers, budgets per period tagged via `LedgerTag`.
- **Content** — `Page` (CMS with granular permissions), `Announcement` (time-bounded), `Shortcut` (team quick links).
- **Communication** — `Gateway` STI (Stripe, Postmark), `Mailbox` for inbound email routing.
- **System** — `Theme` (singleton), `Variable` (typed KV store), `Hook` (event-driven eval), `Report` (named scripts), `AuditLog` (PaperTrail in separate DB).

## Dev setup

```bash
docker compose up -d          # start postgres:16 (localhost:5432, password: password)
bin/setup                     # bundle, yarn, db:migrate (both DBs), clear logs/tmp
bin/dev                       # foreman: web + CSS watcher + SolidQueue worker
```

`bin/dev` uses `Procfile.dev`. Do not run `rails server` alone — the CSS watcher and
background worker will be missing.

Ruby and Node versions live in `.ruby-version` / `.node-version`, mirrored in
`.tool-versions`. CI reads `.ruby-version`, so that file is the authority — keep
`.tool-versions` in step with it.

Development and test connections set `gssencmode: disable` (`config/database.yml`).
The precompiled `pg` gem bundles a libpq built with GSSAPI, and on macOS probing
for credentials loads the system Kerberos frameworks, which segfaults any process
SolidQueue's supervisor forks. Without it `bin/dev` crash-loops the worker.

## Key commands

```bash
bin/rails test                  # unit/controller/model tests
bin/rails test:system           # Capybara system tests (requires Chrome)
bin/rails test test:system      # both (matches CI)
bin/rails db:test:prepare       # reset test DB — run before tests after schema changes

bin/rubocop -A                  # Ruby linting + auto-fix
erb_lint --lint-all -a          # ERB linting + auto-fix
bin/brakeman --no-pager         # security scan

yarn build:css                  # compile SCSS → autoprefixed CSS (one-shot)
yarn watch:css                  # watch mode (already in Procfile.dev)
```

CI runs on pull requests, pushes to `main`, and `v*.*.*` tags. Five jobs run in
parallel: `scan_ruby` (brakeman), `scan_js` (importmap audit), `lint` (rubocop),
`test` (db:test:prepare + test + test:system, against a `postgres:16` service
container), and `build_image` (builds the production Dockerfile without
publishing).

A sixth job, `publish`, runs only on pushes and only after the checks it
depends on pass. It calls `.github/workflows/build.yml` as a reusable workflow,
which pushes multi-arch images to `ghcr.io/<owner>/gatherpack`. `build.yml` has
no trigger of its own apart from `workflow_dispatch`.

`test` is currently **not** in that job's `needs` list: the suite is largely
unmodified scaffold output that has never passed, so gating releases on it would
block publishing entirely. It still runs on every push and pull request. Put it
back in `needs` once the suite is green.

## Production deployment

`docker-compose.production.yml` runs web + worker + PostgreSQL from a published
image; `docker-compose.yml` is development dependencies only. Configuration is
documented in `.env.production.example` and `docs/self-hosting.md`.

The `web` container applies migrations on boot (`bin/docker-entrypoint` runs
`db:prepare`) and the `worker` container runs `bin/jobs`. SolidQueue only runs
inside Puma when `SOLID_QUEUE_IN_PUMA` is not set to `false`.

## Multiple databases (critical)

In development and test there are two databases, and every migration command
must be run for **both**:

```bash
bin/rails db:migrate:primary    # main app DB
bin/rails db:migrate:versions   # PaperTrail audit log DB (separate PostgreSQL DB)
```

`db:migrate` alone only hits the primary. The versions DB has its own migrations in
`db/versions_migrate/` and its own schema at `db/versions_schema.rb`.

Production adds a third, `cable`, backing Solid Cable (`config/cable.yml`).
It is production-only — development uses the `async` adapter and test uses
`test` — so it has no bearing on local migrations. It is schema-only in
practice: `db/cable_schema.rb` defines the single `solid_cable_messages` table
and `db/cable_migrate/` is empty, so `db:prepare` creates it from the schema.
If a Solid Cable upgrade ever ships a migration, it goes in `db/cable_migrate/`
and runs with `bin/rails db:migrate:cable` against `RAILS_ENV=production`.

## JavaScript (importmap, no bundler)

No webpack/esbuild. JS is served via `importmap-rails`. To add a package:

```bash
bin/importmap pin some-package   # pins to CDN
```

Large packages (CodeMirror 6, FullCalendar 6) are vendored as ESM files in
`vendor/javascript/`. Do not put JS through a bundler.

Stimulus controllers live in `app/javascript/controllers/`.

## Custom generators

The scaffold generator is customized — it generates the Rails scaffold **plus** a
Pundit policy and a Gretel breadcrumb config:

```bash
bin/rails generate scaffold Foo bar:string   # scaffold + policy + breadcrumb
bin/rails generate policy Foo               # policy only
bin/rails generate breadcrumb Foo           # breadcrumb config only
```

Templates live in `lib/templates/`.

## Remote modals

Teams are created, viewed and edited from a modal on the index rather than from
separate `new` / `show` / `edit` pages. The pieces:

- `shared/_remote_modal` renders the modal shell around an empty turbo frame.
  Put it on the index page once, outside the search results frame.
- Any link with `data-turbo-frame="<frame_id>"` loads its response into that
  frame, which opens the modal (`remote_modal_controller.js`). The frame is
  emptied on close, so reopening always refetches.
- The controller renders a modal partial when `modal_frame_request?(FRAME)` is
  true and falls through to the normal template otherwise, so `/teams/new` and
  the full team page still work for direct navigation and deep links.
- Forms in the modal carry a hidden `modal=1`. When `modal_submission?` is true,
  create/update/destroy answer with turbo streams that add, replace or remove
  the card plus a flash, instead of redirecting. A successful submit closes the
  modal; a 422 re-renders the form inside it.
- `ModalResponses` (`app/controllers/concerns/`) holds `modal_frame_request?`,
  `modal_submission?` and `modal_flash`.

Anything initialised on `turbo:load` will not run for content fetched into a
frame — hook `turbo:frame-load` as well (see `wireFancyColorInputs` in
`application.js`). Stimulus controllers connect normally either way.

Type records (`TeamType`) are picked with the `creatable_combobox` simple_form
input, which wraps `hotwire_combobox`. Typing a name that matches nothing
switches the hidden field from the foreign key to `name_when_new`, and a
`new_<type>_name` virtual attribute on the model builds the record so
`belongs_to` autosaves it with its parent — nothing is created if the parent
fails validation. Pass `name_when_new` only when the current user is allowed to
create the type on its own, and permit the matching attribute in the controller
and policy on the same condition.

Index pages lay their records out as a grid (`<div id="teams" class="row g-3">`).
The grid cell is part of the record partial, not the page, so a turbo stream can
add, replace or remove a whole cell.

## Settings system

Runtime settings are stored in a PStore file (`storage/settings.pstore`), not in
environment variables or the database. OAuth credentials (Google, Discord, GitHub),
Postmark API key, and feature flags all live here.

Access: `Settings[:key]` anywhere in the app. UI at `/settings`.

The `storage/` directory must be writable. In production it is a mounted persistent
volume.

## Authorization (Pundit)

`app/policies/` has one policy per model. `ApplicationPolicy` defaults **all** actions
to `true` (permissive base). New scaffold-generated policies inherit this and need
explicit restrictions added.

Controller helpers: `admin?`, `architect?`, `manager?`.

## neat_ids

All models use UUID primary keys. The `neat_ids` gem provides human-readable display
IDs with model-specific prefixes (e.g., `usr_…`, `per_…`, `tm_…`).

`ApplicationRecord` has `method_missing` magic for `*_nid=` / `*_nids=` setters that
accept neat IDs and resolve them to UUID foreign keys.


