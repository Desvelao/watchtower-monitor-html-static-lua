## Docker compose

### Setup

1. Copy the example worker config and edit it (site definitions,
   `observable_type`, `ndjson_output`, etc. - see
   [../docs/config.md](../docs/config.md) for the full field reference):
```console
cp worker_config/worker_config.example.lua worker_config/worker_config.lua
```

2. Set `SERVER_API_KEY` and `WATCHTOWER_SERVER_ADDRESS` (a `.env` file next
   to this `docker-compose.yml` works too) - a real API key created via
   `POST /api/auth/api_key` on the target watchtower-server, for a
   user/role with `observables:read`, `observable_types:read`,
   `observations:read`, `observations:create`, and `workers:write` (plus
   whatever other roles this config's `roles` enables need - see
   watchtower-server's `docs/dev/worker-configuration.md`).

### Start

```console
docker compose up
```

### Stop

```console
docker compose stop
```

### Destroy

```console
docker compose down -v
```
