# watchtower_observer_web_scraper (`watchtower-observer-web-scraper` rock)

The `"web_scraper"` observer-type implementation for
[watchtower-worker-core](https://github.com/Desvelao/watchtower-server/tree/main/shared/watchtower_worker_core)'s
`observer_registry`: static-HTML scraping via the vendored `webscraper` rock,
an ad-hoc "test an observer config against a URL" poller, heartbeat
self-reporting, and an opt-in `ndjson_output` observation side-channel (see
below) - a worker entry point needs exactly one
`require("watchtower_observer_web_scraper")` (or
`require("watchtower_observer_web_scraper.plugin")` for a
`watchtower_worker_core.lifecycle`-based one) to get everything below. No
DB/HTTP-provider-specific code of its own; everything it needs comes from
`context.connector`, the one runtime-transport object every
`watchtower_worker_core.lifecycle` consumer already provides - including the
outbound fetch transport, `scraper_creator.new`'s injectable `transport`
param, picked automatically by `watchtower_observer_web_scraper.plugin`
(OpenResty's non-blocking `resty.http`, when available, or the vendored
rock's own blocking default otherwise - see "Outbound fetch transport"
below).

Originally extracted from [watchtower-server](https://github.com/Desvelao/watchtower-server)'s
`worker_plugins/watchtower_observer_web_scraper/`; this repository is now this
plugin's own home/distribution repo - see the repo root `README.md` for how to
run it as a Docker image against a `watchtower-server` deployment.

## Modules

- **`watchtower_observer_web_scraper`** (this directory's `init.lua`) -
  the package's entry point for a consumer not using
  `watchtower_worker_core.lifecycle` at all. Requiring it exposes:
  - `M.new_registry(observers_config, deps)` - a decoupled construction
    facade wrapping `watchtower_worker_core.observer_registry.new(observers_config,
    { web_scraper = observers.web_scraper.new }, deps)`, so a consumer
    never requires `observer_registry` or `observers.web_scraper` directly.
- **`watchtower_observer_web_scraper.plugin`** - the
  `watchtower_worker_core.lifecycle` plugin form of the above, and the
  entry point an actual worker (both watchtower-server's own) appends to
  its plugin list. Registers the "web_scraper" observer type explicitly,
  inside its own `setup(context, deps)`
  (`context.observer_types:register_type("web_scraper", observers.web_scraper.new)`
  - a registry `watchtower_worker_core.lifecycle.build` creates fresh per
  build call, not a require-time side effect on any module-global table -
  see `watchtower_worker_core.observer_registry`'s own
  `M.new_type_registry`), and the ad-hoc test-poller task, building its own
  `fetch_remote_sites`/test-poller deps directly from `context.connector`'s
  `next_observer_test`/`get_observer_config`/`list_observer_config_targets`/
  `observer_test_triggering`/`observer_test_ack`/`observer_test_error`
  methods (only needed for a `sites_source="remote"` observer entry or the
  test poller - a `connector` that only ever serves `sites_source="local"`
  entries needs none of them) rather than ever referencing an HTTP provider
  or DB models itself. The one thing it doesn't derive from `connector`'s
  named methods is the outbound fetch transport - it picks that from
  `connector.connection_type` instead, see "Outbound fetch transport"
  below. This is the entry point a worker
  built on `watchtower_worker_core.lifecycle.build(plugins, context)`
  actually appends to its plugin list; `M.new_registry` above stays
  available as a lower-level primitive this plugin is built on, for a
  consumer not using the lifecycle kernel at all.
- **`watchtower_observer_web_scraper.scraper_creator`** - `M.new(sites, transport)`
  builds a `WebScraper` instance (the vendored `webscraper` rock) with
  every filter/validator registered and each entry of `sites`
  (`{name, urls_match, fields, urls_test, headers, ssl_verify, expect_selector,
  block_selector, block_text}`) registered as a scrapeable site. Returns
  `(webscraper, capabilities)` - `capabilities` is the sorted,
  de-duplicated array of registered site names, for heartbeat
  self-reporting. `transport` (optional) overrides the instance's own
  `_fetch`, the seam a caller uses to inject a non-blocking (e.g.
  cosocket-based) fetch instead of the rock's own default blocking one.
- **`watchtower_observer_web_scraper.observers.web_scraper`** - the
  `"web_scraper"` observer type, a pure builder module with no import-time
  side effects (registered explicitly by `watchtower_observer_web_scraper.plugin`/
  `.init`'s `M.new_registry` above, not self-registered).
  `M.new(observer_config, deps)`
  builds an instance from a `sites` array (`sites_source="local"`,
  default) or fetches one via `deps.fetch_remote_sites`
  (`sites_source="remote"`, kept fresh afterward by its own
  `:maintenance_tasks()`-registered task, on `remote_sites_refresh_interval`
  seconds - aggregated by `observer_registry:maintenance_tasks()` into
  `watchtower_worker_core.lifecycle`'s task list, not checked inline on
  every `:run`). Implements the full observer contract:
  `:run(observable, observable_type)` (scrapes, coerces the always-string
  result into the observable type's `observation_schema`-typed
  properties, and writes an `ndjson_output` line if configured - see below),
  `:capabilities()`, `:reportable_config(observer_config)`
  (the safe-to-report field allow-list for heartbeats), and
  `:maintenance_tasks()` (empty for a `sites_source="local"` instance).
- **`watchtower_observer_web_scraper.observer_config_test_poller`** -
  `M.resolve_sites(test_config, source)` / `M.poll_and_run(deps, logger)`, an
  ad-hoc "test this observer config against a URL" poller used by both
  worker runtimes, independent of any real observable/observable type.

See watchtower-server's
[`shared/watchtower_worker_core/README.md`](https://github.com/Desvelao/watchtower-server/blob/main/shared/watchtower_worker_core/README.md)'s
"Writing a new observer type"/"Writing a new task plugin" sections for the
`:run`/`:capabilities`/`:reportable_config`/`:maintenance_tasks` instance
contract this package's own observer type implements, and how
`watchtower_observer_web_scraper.plugin` registers it via
`context.observer_types` rather than self-registration; and
[`docs/dev/worker-configuration.md`](https://github.com/Desvelao/watchtower-server/blob/main/docs/dev/worker-configuration.md)
for the full `WORKER_CONFIG_FILE` field reference (`plugins`,
`observer.observers`, etc.) this package's own fields sit inside.

## `ndjson_output`: writing observations to a local NDJSON file

Any `observer.observers` entry of `type = "web_scraper"` may set an optional
`ndjson_output` field:

```lua
{
  id = "product_scraper",
  type = "web_scraper",
  observable_type = "product",
  sites = { ... },
  ndjson_output = {
    file = "/data/observations.ndjson", -- required
    fields = { "price", "discount", "available" }, -- optional allow-list; omitted = every extracted property
  },
}
```

On every successful scrape (after the usual `observation_schema` coercion),
one JSON line is appended to `file`:

```json
{"observable_id":42,"observable_name":"example-product","observable_type":"product","properties":{"price":19.99,"available":true},"observed_at":"2026-09-26T10:00:00Z"}
```

This is a pure side-channel - independent of, and in addition to, the
observation still being posted to the watchtower server normally. A write
failure (bad path, missing directory, no permissions) only logs a warning;
it never fails the observe itself. Encoding uses `cjson.safe` (already a
dependency of every consumer of this package, and the JSON library used
throughout `watchtower_worker_core` itself) - not `dkjson`.

## Outbound fetch transport

Unlike most of this package, the outbound scrape-fetch transport isn't left
entirely to a consumer to inject: `watchtower_observer_web_scraper.plugin`'s
`Plugin.setup` picks it internally (`build_scraper_transport`), based on
`context.connector.connection_type`. When that's `"embedded"` (an
OpenResty-hosted consumer), it requires
`watchtower_observer_web_scraper.resty_transport` - a non-blocking,
cosocket-based (`resty.http`) fetch, needed because the vendored
`webscraper` rock's own default `_fetch` is a blocking LuaSocket/LuaSec call
that would stall an nginx worker's event loop - and passes it to
`scraper_creator.new`'s `transport` param. That `require` is guarded by
`pcall`, so a consumer without `lua-resty-http` installed (or any other
`connection_type`, e.g. the standalone worker's plain Lua 5.1 process) falls
back to `scraper_creator`'s own default (the vendored rock's blocking fetch,
harmless outside an nginx worker process) instead of failing setup.

## What stayed out and why

- **`server/lib/observer_field_schema.lua`**, **`server/plugins/observer_configs/`**,
  **`server/models/observer_configs.lua`**, **`server/models/observer_config_test_requests.lua`** -
  the server-side admin CRUD/validation for centrally-managed observer
  configs. Kept in watchtower-server itself, not this package, since it's
  generic-observable-type admin machinery, not observer-type-specific
  behavior.
- **A consuming repo's own dev/test-only `WORKER_CONFIG_FILE` fixtures** -
  e.g. a small `.lua` file returning just the `observer.observers` entry
  and `plugins` declaration this package needs, for a repo's own local test
  harness to `require()`. Such a file may live alongside this package's own
  modules, but is deliberately **not** part of the installable rock - it
  must not be added to this directory's own `.rockspec`'s `build.modules`
  list, since it's specific to one consuming repo's dev setup, not this
  package's own distributable code (see `docker/images/prod/worker_config.default.lua`
  at the repo root, which is exactly such a fixture - baked into this repo's
  own Docker image, not into this rockspec).

## A note on `webscraper`

`scraper_creator` requires `webscraper`/`webscraper.filters.filters`/
`webscraper.filters.validators` at runtime - a published LuaRocks package
(github.com/Desvelao/webscrapper), declared as an ordinary rockspec
`dependency` here and pulled in normally by `luarocks make`/`install`.
Every module in this package needs it - there's no optional path around
it the way `watchtower-worker-core` has for `pling`.

`webscraper`'s own `xml` dependency doesn't build cleanly under `luarocks
3.x` from its upstream rockspec - a plain `luarocks install` of this package
(outside this repo's own Docker images, which handle it automatically - see
below) needs that same fix applied first: install
`docker/rockspecs/xml-1.1.3-1.rockspec` from a `REL-1.1.3` checkout of
[lubyk/xml](https://github.com/lubyk/xml) before installing `webscraper`
itself - see that rockspec's own header comment and
`docker/images/prod/Dockerfile` for the exact recipe.

## Install

```console
luarocks install watchtower-observer-web-scraper
```

or, as this repo's own Docker images already do it: install
`docker/rockspecs/xml-1.1.3-1.rockspec` and
`docker/rockspecs/watchtower-observer-web-scraper-deps-1.0-1.rockspec` (see
"A note on `webscraper`" above), then `COPY` this directory straight onto
`/worker_plugins/watchtower_observer_web_scraper/` inside a
`ghcr.io/desvelao/watchtower-worker` base image, which already provides
`lua-cjson` and `watchtower_worker_core` with `/worker_plugins` already on
`LUA_PATH` - see the repo root `README.md` and
`docker/images/prod/Dockerfile`.
