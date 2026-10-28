-- Default WORKER_CONFIG_FILE baked into this image (see
-- docker/images/prod/Dockerfile) at /app/worker_config.default.lua, so the
-- image is runnable out of the box. For real use, mount your own file over
-- this path (or point WORKER_CONFIG_FILE at a different mounted path
-- instead - see prod/docker-compose.yml) with your own `sites`/
-- `server.address`/API key.
--
-- Every field below (and every one commented out) is documented in full in
-- watchtower-server's own docs/dev/worker-configuration.md and
-- docker/worker/worker_config.example.lua - this file only sets what this
-- image actually needs to observe out of the box, plus commented-out
-- starter blocks for the other worker roles this same base image supports,
-- so enabling one is "uncomment two things", not "go read another repo".
return {
  version = "0.1.0-alpha2",

  -- This image's job is the "web_scraper" observer. Uncomment `roles` below
  -- (and the matching commented-out role section) to also run
  -- scheduler/analyzer/evaluator/deliver from this same worker process.
  roles = { "observer" },
  -- roles = { "observer", "scheduler" },
  -- roles = { "observer", "scheduler", "analyzer", "evaluator", "deliver" },

  -- Makes the "web_scraper" observer type available - see this repo's own
  -- src/README.md.
  plugins = { "watchtower_observer_web_scraper.plugin" },

  observer = {
    -- "queue" (default): only claims work a "scheduler"-role tick queued -
    -- observes nothing until a scheduler_tasks task exists on the server.
    -- "interval": continuously polls the stalest enabled observable instead,
    -- with no scheduler_tasks needed - simplest way to see this run once.
    source = "queue",
    -- source = "interval",

    observers = {
      {
        id = "product_scraper",
        type = "web_scraper",
        -- Must match an observable_types.name already created on the
        -- target watchtower-server, with an observation_schema declaring
        -- whatever fields your sites' own `fields` below extract (e.g.
        -- price/discount/available/url).
        observable_type = "product",

        sites_source = "local",
        -- Fill in with your own scraper site definitions, or mount your
        -- own worker_config.lua over this file entirely - see
        -- prod/docker-compose.yml. Same shape as watchtower-server's own
        -- POST /api/observer_configs body:
        -- sites = {
        --   {
        --     name = "example-site",
        --     urls_match = { "^https?://example%.com/" },
        --     fields = {
        --       price = { selector = { ".price" } },
        --       discount = { selector = { ".discount" } },
        --       available = { selector = { ".availability" } },
        --     },
        --   },
        -- },
        sites = {},

        -- Opt-in: append each successfully scraped observation as a JSON
        -- line to this file, independent of it also being posted to the
        -- server - see this repo's own src/README.md.
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
  --   source = "queue", -- "interval" re-runs matching on a fixed cadence instead
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
    -- Override with WATCHTOWER_SERVER_ADDRESS (see prod/docker-compose.yml)
    -- rather than editing this file directly, when possible.
    address = os.getenv("WATCHTOWER_SERVER_ADDRESS") or "http://server:8080",
    -- api_key resolution: SERVER_API_KEY_FILE > SERVER_API_KEY env >
    -- server.api_key here (least secure) - see prod/docker-compose.yml.
  },
}
