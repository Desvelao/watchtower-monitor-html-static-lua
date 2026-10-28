# Configuration

This image is a `watchtower-server` standalone worker
(`ghcr.io/desvelao/watchtower-worker`) with the
`watchtower_observer_web_scraper` plugin baked in. Configuration is the
same `WORKER_CONFIG_FILE` mechanism every `watchtower-server` worker uses -
see that project's own
[`docs/dev/worker-configuration.md`](https://github.com/Desvelao/watchtower-server/blob/main/docs/dev/worker-configuration.md)
for the full, generic field reference (`roles`, `plugins`, every role's own
`interval`/`source`, the server API key resolution chain, etc.). This
document only covers what's specific to **this** image and plugin.

## Enabling the plugin

Already done by the image's baked-in default
(`docker/images/prod/worker_config.default.lua`, also mirrored at
`prod/worker_config/worker_config.example.lua` for you to copy and edit):

```lua
plugins = { "watchtower_observer_web_scraper.plugin" },
```

## `observer.observers` entries (`type = "web_scraper"`)

| Field | Required | Description |
| --- | --- | --- |
| `id` | yes | This entry's own identifier - used in logs/heartbeats. |
| `type` | yes | Always `"web_scraper"` for this plugin. |
| `observable_type` | yes | Must match an `observable_types.name` already created on the target `watchtower-server` (e.g. `"product"`), with an `observation_schema` declaring whatever fields your `sites.*.fields` below extract. |
| `url_property` | no (default `"url"`) | Which of the Observable's own `properties` holds the URL to scrape. |
| `sites_source` | no (default `"local"`) | `"local"`: read `sites` below, static. `"remote"`: fetch the current site list from the server's Observer Configs feature instead (`GET /api/observer_configs/site`) - requires `remote_source = "observer_configs"` and `observable_type_id` below, and an API key with `observer_configs:read`. |
| `remote_source` | only with `sites_source="remote"` | Always `"observer_configs"` - the only supported remote source. |
| `observable_type_id` | only with `sites_source="remote"` | The numeric `observable_types.id` to fetch sites for. |
| `remote_sites_refresh_interval` | no (default `60`) | Seconds between this one entry's own remote site-list refresh (`sites_source="remote"` only). |
| `sites` | only with `sites_source="local"` | Array of `{name, urls_match, fields, urls_test?, headers?, ssl_verify?, expect_selector?, block_selector?, block_text?}` - same shape as the server's own `POST /api/observer_configs` body. |
| `ndjson_output` | no | See below - this plugin's own addition, not part of upstream `watchtower-server`. |

## `ndjson_output`: writing observations to a local NDJSON file

```lua
ndjson_output = {
  file = "/data/observations.ndjson", -- required
  fields = { "price", "discount", "available" }, -- optional allow-list; omitted = every extracted property
}
```

On every successful scrape, one JSON line is appended to `file`:

```json
{"observable_id":42,"observable_name":"example-product","observable_type":"product","properties":{"price":19.99,"available":true},"observed_at":"2026-09-26T10:00:00Z"}
```

This happens in addition to (not instead of) the observation being posted
to the server normally - it's a local audit trail / integration point for
consuming the same data outside `watchtower-server`. A write failure (bad
path, missing directory, no permissions) only logs a warning and never
fails the observe itself. Both `dev/docker-compose.yml` and
`prod/docker-compose.yml` mount a `data/` directory at `/data` for this.

See `src/README.md` for the full implementation notes.
