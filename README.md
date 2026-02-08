[![RubyMine](https://www.elegantobjects.org/rubymine.svg)](https://www.jetbrains.com/ruby/)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

# Mudis Web Cache

Rack + Puma web cache server for [Mudis](https://github.com/kiebor81/mudis). This app runs Mudis in IPC mode inside the Puma master process and exposes HTTP endpoints for cache interaction. It bundles `mudis-cli` and `mudis-ql` by default.

## Requirements

- Ruby >= 3.3
- Docker (optional)

## Quick Start (Docker Compose)

```bash
cd mudis-web-cache

docker compose -f docker-compose.yml up --build
```

App will listen on `http://localhost:3000`.

By default, the compose file enables Mudis soft persistence and writes snapshots to `./data/mudis_snapshot.dump`
(mounted into the container at `/data`).

## Local Start (No Docker)

```bash
cd mudis-web-cache

bundle install
bundle exec puma -C config/puma.rb
```

## Endpoints

All responses are JSON.

- `GET /health`
- `GET /metrics`
- `POST /metrics/reset`
- `POST /reset`
- `GET /cache/:key?namespace=...`
- `POST /cache/:key?namespace=...`
- `PUT /cache/:key?namespace=...`
- `DELETE /cache/:key?namespace=...`
- `GET /cache/:key/inspect?namespace=...`
- `GET /exists/:key?namespace=...`
- `GET /keys?namespace=...`
- `DELETE /namespace/:namespace`
- `GET /least-touched?count=10`
- `POST /ql`
- `GET /docs`
- `GET /openapi.json`

## Authentication (JWT)

JWT authentication is enabled by default. Set `MUDIS_JWT_ENABLED=false` to opt out.

Requests must include a bearer token:

```bash
curl -H "Authorization: Bearer <token>" "http://localhost:3000/cache/user:42?namespace=users"
```

Admin endpoints require an admin token (separate from read/write tokens). Admin endpoints:

- `POST /reset`
- `POST /metrics/reset`
- `DELETE /namespace/:namespace`

The default admin check looks for a `role` claim set to `admin`. You can change the claim name/value with env vars.

Example admin claim payload:

```json
{"sub":"service","role":"admin"}
```

### Token Minting

This service does not issue tokens. Callers must mint their own JWTs (signed with `MUDIS_JWT_SECRET` and using `MUDIS_JWT_ALGORITHM`) and include them as a bearer token on each request.

### Default Secret Generation

If you are not using Docker, you still need to set `MUDIS_JWT_SECRET` before starting the server. For local development and testing, prefer a deterministic secret so your tokens stay valid across restarts:

```bash
# Bash
export MUDIS_JWT_SECRET="dev-secret"
```

```powershell
# PowerShell
$env:MUDIS_JWT_SECRET = "dev-secret"
```

```bash
# Ruby
ruby -e "puts 'dev-secret'"
```

### Local Opt-out

You can disable JWT locally by setting `MUDIS_JWT_ENABLED=false` before starting the server.

```bash
# Bash
export MUDIS_JWT_ENABLED="false"
bundle exec puma -C config/puma.rb
```

```powershell
# PowerShell
$env:MUDIS_JWT_ENABLED = "false"
bundle exec puma -C config/puma.rb
```

```bash
# Ruby
ruby -e "ENV['MUDIS_JWT_ENABLED']='false'; exec('bundle exec puma -C config/puma.rb')"
```

### Caller Binding (Opt-in)

You can opt in to per-caller isolation by binding a namespace to a JWT claim. When enabled, the service derives the namespace from the claim and ignores client-supplied namespaces (rejecting mismatches).

Example: with `MUDIS_BIND_NAMESPACE_CLAIM=sub` and `MUDIS_BIND_PREFIX=caller:`, a token with `{"sub":"acme"}` is bound to namespace `caller:acme`.

### Write Example

```bash
curl -X POST "http://localhost:3000/cache/user:42?namespace=users" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"value": {"name": "Ada", "age": 38}, "expires_in": 60}'
```

### Read Example

```bash
curl -H "Authorization: Bearer <token>" "http://localhost:3000/cache/user:42?namespace=users"
```

### Mudis-QL Example

```bash
curl -X POST "http://localhost:3000/ql" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "namespace": "users",
    "where": {"age": {"range": [30, 50]}},
    "order": {"field": "age", "direction": "asc"},
    "limit": 10,
    "action": "all"
  }'
```

Supported QL payload fields:

- `namespace` string or null
- `where` hash of field to condition
- `order` as `{ "field": "age", "direction": "asc" }` or a field string
- `limit` integer
- `offset` integer
- `action` one of `all`, `first`, `last`, `count`, `exists`, `pluck`, `sum`, `average`, `group_by`
- `fields` array for `pluck`
- `field` string for `sum`, `average`, `group_by`

Supported `where` conditions:

- Equality: `{ "status": "active" }`
- Regex: `{ "name": {"regex": "^A", "flags": "i"} }`
- Range: `{ "age": {"range": [18, 30]} }`
- In list: `{ "role": {"in": ["admin", "editor"]} }`

## Swagger UI

Open `http://localhost:3000/docs` for interactive API docs. The OpenAPI spec is available at `http://localhost:3000/openapi.json`.

## CLI Inside Container

The image includes `mudis-cli`. This wrapper is intended for IPC usage only and connects to the running cache via IPC. Use it for runtime interaction:

```bash
docker exec -it <container> ./bin/mudis keys --namespace users
```

The CLI process is a separate client that connects to the cache over IPC. If IPC mode is disabled, the CLI will exit with an error.

## Configuration (Docker Args / ENV)

- `PORT` (default `3000`)
- `RACK_ENV` (default `production`)
- `WEB_CONCURRENCY` (default `2`)
- `PUMA_THREADS` (default `5`)
- `MUDIS_SERIALIZER` (`json`, `marshal`, `oj`)
- `MUDIS_JWT_ENABLED` (`true`/`false`, default `true`)
- `MUDIS_JWT_SECRET` (required when JWT is enabled)
- `MUDIS_JWT_ALGORITHM` (default `HS256`)
- `MUDIS_JWT_ISSUER` (optional)
- `MUDIS_JWT_AUDIENCE` (optional)
- `MUDIS_JWT_ADMIN_CLAIM` (default `role`)
- `MUDIS_JWT_ADMIN_VALUE` (default `admin`)
- `MUDIS_BIND_ENABLED` (`true`/`false`, default `false`)
- `MUDIS_BIND_NAMESPACE_CLAIM` (default `sub`)
- `MUDIS_BIND_PREFIX` (default empty)
- `MUDIS_COMPRESS` (`true`/`false`)
- `MUDIS_MAX_VALUE_BYTES`
- `MUDIS_HARD_MEMORY_LIMIT` (`true`/`false`)
- `MUDIS_MAX_BYTES`
- `MUDIS_BUCKETS`
- `MUDIS_MAX_TTL`
- `MUDIS_DEFAULT_TTL`
- `MUDIS_EXPIRY_INTERVAL` (seconds, default `60`)
- `MUDIS_PERSISTENCE_ENABLED` (`true`/`false`)
- `MUDIS_PERSISTENCE_PATH`
- `MUDIS_PERSISTENCE_FORMAT` (`json` or `marshal`)
- `MUDIS_PERSISTENCE_SAFE_WRITE` (`true`/`false`)
- `MUDIS_FORCE_TCP` (`true`/`false`) for IPC over TCP (Windows or dev)
- `MUDIS_IPC_MODE` (`true`/`false`, default `true`)
- `MUDIS_SSL_ENABLED` (`true`/`false`)
- `MUDIS_SSL_PORT` (defaults to `PORT`)
- `MUDIS_SSL_CERT` (path to cert PEM)
- `MUDIS_SSL_KEY` (path to key PEM)
- `MUDIS_SSL_VERIFY_MODE` (default `none`)
- `MUDIS_SSL_CA` (path to CA bundle PEM)
- `MUDIS_SSL_MIN_VERSION`
- `MUDIS_SSL_MAX_VERSION`

Notes:

- IPC mode is enabled via Puma preload + IPC server in `config/puma.rb` when `MUDIS_IPC_MODE=true` and workers > 0.
- When `MUDIS_PERSISTENCE_ENABLED=true`, the server loads the snapshot on startup and saves it on exit (via the Mudis persistence hook).
- `MUDIS_PERSISTENCE_PATH` controls where the snapshot is written (only when persistence is enabled). In containers, set this to a mounted path or shared volume.
- On Windows, Puma workers are disabled automatically (worker mode not supported).
- For `MUDIS_SERIALIZER=oj`, you must add the `oj` gem (not included by default).
- SSL is optional. When enabled, you must supply `MUDIS_SSL_CERT` and `MUDIS_SSL_KEY`.
