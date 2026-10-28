-- Public entry point for the `watchtower-observer-web-scraper` LuaRocks
-- package - see README.md in this directory. `observers.web_scraper` is a
-- pure builder module with no import-time side effects (no
-- self-registration) - M.new_registry below passes its `M.new` explicitly
-- as observer_registry.new's own `observer_type_builders` argument, so a
-- worker entry point needs exactly one `require("watchtower_observer_web_scraper")`
-- and never touches watchtower_worker_core.observer_registry or
-- observers.web_scraper itself. A watchtower_worker_core.lifecycle-based
-- consumer instead uses `watchtower_observer_web_scraper.plugin`, which
-- registers the same `observers.web_scraper.new` into the lifecycle's own
-- per-build registry (context.observer_types) rather than through this
-- facade at all.
local observer_registry = require("watchtower_worker_core.observer_registry")
local web_scraper_observer = require("watchtower_observer_web_scraper.observers.web_scraper")

local M = {}

-- The package's own decoupled construction facade: a worker passes its
-- `observer.observers` config array (e.g.
-- {{id="product_scraper", type="web_scraper", observable_type="product", ...}})
-- and its own I/O deps (fetch_remote_sites, scraper_transport) and gets
-- back a ready-to-use registry.
function M.new_registry(observers_config, deps)
	return observer_registry.new(observers_config, { web_scraper = web_scraper_observer.new }, deps)
end

return M
