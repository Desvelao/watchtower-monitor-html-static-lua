-- Copy to worker_config.lua (gitignored) and edit - see prod/README.md and
-- prod/docker-compose.yml, which mounts this file over the image's own
-- baked-in default (docker/images/prod/worker_config.default.lua). Every
-- field below (and every one commented out) is documented in full in
-- watchtower-server's own docs/dev/worker-configuration.md.
return {
  version = "0.1.0-alpha2",

  -- This image's job is the "web_scraper" observer. Uncomment `roles` below
  -- (and the matching commented-out role section) to also run
  -- scheduler/analyzer/evaluator/deliver from this same worker process.
  roles = { "observer" },
  -- roles = { "observer", "scheduler" },
  -- roles = { "observer", "scheduler", "analyzer", "evaluator", "deliver" },

  plugins = { "watchtower_observer_web_scraper.plugin" },

  observer = {
    source = "queue",
    -- source = "interval",

    observers = {
      {
        id = "product_scraper",
        type = "web_scraper",
        -- Must match an observable_types.name already created on the
        -- target watchtower-server.
        observable_type = "product",

        sites_source = "local",
        sites = {
          -- {
          --   name = "example-site",
          --   urls_match = { "^https?://example%.com/" },
          --   fields = {
          --     price = { selector = { ".price" } },
          --     discount = { selector = { ".discount" } },
          --     available = { selector = { ".availability" } },
          --   },
          -- },
        },

        -- Opt-in: append each successfully scraped observation as a JSON
        -- line to this file (mounted via prod/docker-compose.yml's `data`
        -- volume), independent of it also being posted to the server.
        ndjson_output = {
          file = "/data/observations.ndjson",
        },
      },
    },
  },

  -- -- Uncomment together with `roles` above to also fire due
  -- -- scheduler_tasks from this worker.
  -- scheduler = {
  --   interval = 30,
  --   reap_stale = { interval = 60, timeout_seconds = 300 },
  -- },

  -- -- Uncomment together with `roles` above to re-run rule matching against
  -- -- already-observed data (needs rules:read, observables:read,
  -- -- observable_types:read, observations:read, alerts:read, alerts:create
  -- -- on the API key below).
  -- analyzer = {
  --   source = "queue",
  -- },

  -- -- Uncomment together with `roles` above to match alerts against
  -- -- notification_policies and enqueue deliveries (needs alerts:read,
  -- -- policies:read, workers:write).
  -- evaluator = {
  --   source = "queue",
  --   reap_stale = { interval = 60, timeout_seconds = 300 },
  -- },

  -- -- Uncomment together with `roles` above to actually send queued
  -- -- deliveries (needs workers:write; smtp.* only for "email" channels).
  -- deliver = {
  --   source = "deliveries",
  --   -- smtp = { host = "smtp.gmail.com", port = 465, user = "...", from = "...", ssl = true },
  -- },

  server = {
    address = os.getenv("WATCHTOWER_SERVER_ADDRESS") or "http://server:8080",
  },
}
