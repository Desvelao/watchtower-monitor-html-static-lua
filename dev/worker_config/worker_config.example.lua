-- Dev WORKER_CONFIG_FILE - copy to worker_config.lua (gitignored) and edit.
-- See ../../docker/images/prod/worker_config.default.lua for the same
-- shape with every field's full documentation, and watchtower-server's own
-- docs/dev/worker-configuration.md for the complete field reference.
return {
  version = "0.1.0-alpha2",
  interval = "0 * * * *",
  heartbeat_interval = 30,
  worker_id = "watchtower-worker-web-scraper",
  mode = 'sequence-interval',
  sequence_interval = 30,
  roles = { "observer" },
  plugins = { "watchtower_observer_web_scraper.plugin" },

  observer = {
    -- "interval" for local dev: no scheduler_tasks needed to see it scrape.
    source = "interval",
    interval = 30,

    test_poll = {
      enabled = true,
      interval = 30
    },

    observers = {
      {
        id = "product_scraper1",
        type = "web_scraper",
        observable_type = "product",
        sites_source = "remote",
        remote_source = "observer_configs",
        observable_type_id = 1,
        ndjson_output = {
          file = "/data/observations1.ndjson",
        },
      },
      {
        id = "product_scraper2",
        type = "web_scraper",
        observable_type = "product", -- must already exist on the target server
        sites_source = "local",
        sites = {
          {
            name = "example-site",
            urls_match = { "^https?://example%.com/" },
            fields = {
              price = { selector = { ".price" } },
              discount = { selector = { ".discount" } },
              available = { selector = { ".availability" } },
            },
          },
        },
        ndjson_output = {
          file = "/data/observations2.ndjson",
        },
      },
    },
  },

  server = {
    address = os.getenv("WATCHTOWER_SERVER_ADDRESS") or "http://server:8080",
    -- api_key = "akey_...", -- prefer SERVER_API_KEY env instead
  },
}
