package = "watchtower-observer-web-scraper"
version = "0.1.0-1"
source = {
  url = "git+https://github.com/Desvelao/watchtower-monitor-html-static-lua",
  tag = "v0.1.0-alpha2",
}
description = {
  summary = "The 'web_scraper' observer-type implementation for watchtower-worker-core: a static-HTML WebScraper wrapper, an ad-hoc config-test poller, heartbeat self-reporting, and an opt-in NDJSON observation output.",
  detailed = [[
    Extracted from watchtower-server (github.com/Desvelao/watchtower-server),
    now maintained here as this plugin's own distribution repo. Plugs into
    watchtower_worker_core.observer_registry as the "web_scraper" observer
    type: builds a WebScraper instance per site list (local, or
    remotely-fetched and self-refreshing), coerces its always-string field
    extraction into an observable type's observation_schema-typed
    properties, and reports its own safe-to-report config subset for
    heartbeats. Also ships an ad-hoc "test a scraper config against a URL"
    poller, and an opt-in `ndjson_output` observer-config field that appends
    each successfully scraped observation as a JSON line to a local file.
    No DB/HTTP-provider-specific code of its own; the outbound fetch
    transport is picked automatically (OpenResty's non-blocking resty.http,
    when available, or the vendored rock's own blocking default otherwise -
    see scraper_creator.new's `transport` param and the README).
  ]],
  homepage = "https://github.com/Desvelao/watchtower-monitor-html-static-lua",
  license = "MIT",
}
dependencies = {
  "lua >= 5.1, < 5.4",
  -- watchtower-worker-core is NOT published to LuaRocks (it ships as
  -- watchtower-server's own shared/ - see that repo's own docs), so it's
  -- deliberately not declared here; a `luarocks install` of this package
  -- alone would otherwise always fail resolving it. This package still
  -- requires it at runtime (require("watchtower_worker_core.*")) - whatever
  -- consumes this rock must provide it on LUA_PATH itself, exactly as this
  -- repo's own Docker images do (baking watchtower-server's shared/ in).
  "webscraper == 0.2.0-1",
}
build = {
  type = "builtin",
  modules = {
    ["watchtower_observer_web_scraper.init"] = "init.lua",
    ["watchtower_observer_web_scraper.plugin"] = "plugin.lua",
    ["watchtower_observer_web_scraper.scraper_creator"] = "scraper_creator.lua",
    ["watchtower_observer_web_scraper.resty_transport"] = "resty_transport.lua",
    ["watchtower_observer_web_scraper.observer_config_test_poller"] = "observer_config_test_poller.lua",
    ["watchtower_observer_web_scraper.observers.web_scraper"] = "observers/web_scraper.lua",
  },
}
