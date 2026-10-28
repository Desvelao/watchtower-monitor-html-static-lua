-- The "web_scraper" watchtower_worker_core.lifecycle plugin: the one place
-- both worker runtimes register this observer type AND its two pieces of
-- recurring behavior that are specific to it, not generic worker-core
-- concepts - the ad-hoc "test this scraper config against a URL" poller
-- (observer_config_test_poller.lua) and (via observer_registry:maintenance_tasks(),
-- see observers/web_scraper.lua's own :maintenance_tasks()) each configured
-- sites_source="remote" instance's own site-list refresh.
--
-- Stays free of DB/HTTP-provider-specific code, per this package's own
-- README: it never references http_provider/models/job_manager itself.
-- Instead everything it needs - including the observer_configs/
-- observer_config_test_requests methods build_observer_config_deps below
-- wraps - comes from context.connector, the one runtime-transport object
-- every watchtower_worker_core.lifecycle consumer already provides (see
-- that module's own header comment). This is what lets a worker entry
-- point (worker/lua/main.lua/server/workers/observe_pending_worker.lua) load
-- this plugin with no plugin-specific wiring of its own beyond naming its
-- module path in config.plugins - no per-runtime adapter module, no
-- bespoke context field. It only works when context.connector implements
-- the six method names build_observer_config_deps calls
-- (next_observer_test/get_observer_config/list_observer_config_targets/
-- observer_test_triggering/observer_test_ack/observer_test_error - see that
-- function below), needed only for a sites_source="remote" observer entry
-- or the ad-hoc test poller; a consumer using only sites_source="local"
-- entries needs none of them.
--
-- The outbound scrape fetch transport is the one thing this plugin picks
-- itself rather than deriving from a connector method (see
-- build_scraper_transport below): the choice is just "does this runtime
-- have OpenResty's cosocket API or not" - a fact
-- context.connector.connection_type already states directly.
local web_scraper_observer = require("watchtower_observer_web_scraper.observers.web_scraper")
local observer_config_test_poller = require("watchtower_observer_web_scraper.observer_config_test_poller")

local Plugin = { name = "web_scraper" }

-- Builds fetch_remote_sites/observer_config_test_poller_deps purely from
-- context.connector's own method names - identical on both worker runtimes
-- (provider_http.lua already has all six; embedded_provider in
-- server/workers/observe_pending_worker.lua mirrors them 1:1, direct-DB
-- instead of HTTP). `scraper_transport`/`logger` are filled in by the
-- caller (Plugin.setup below), not here.
local function build_observer_config_deps(connector)
	local function fetch_remote_sites(observer_config)
		if observer_config and observer_config.remote_source == "observer_configs" then
			if not connector.list_observer_config_targets then
				return nil, "connector does not support observer_configs-backed sites"
			end
			local rows, err = connector:list_observer_config_targets(observer_config.observable_type_id)
			if not rows then
				return nil, err
			end
			local sites = {}
			for i, row in ipairs(rows) do
				sites[i] = observer_config_test_poller.to_site(row.name, row.fields, row.mechanism_config)
			end
			return sites
		end
		return nil, "unsupported remote_source: " .. tostring(observer_config and observer_config.remote_source)
	end

	return fetch_remote_sites,
		{
			fetch_pending = function()
				return connector:next_observer_test()
			end,
			get_observer_config = function(id)
				return connector:get_observer_config(id)
			end,
			list_observer_config_targets = function(observable_type_id)
				return connector:list_observer_config_targets(observable_type_id)
			end,
			report_triggering = function(id)
				return connector:observer_test_triggering(id)
			end,
			report_result = function(id, result)
				return connector:observer_test_ack(id, result)
			end,
			report_error = function(id, message)
				return connector:observer_test_error(id, message)
			end,
		}
end

-- Picks the outbound scrape-fetch transport for scraper_creator.new: the
-- non-blocking, cosocket-based resty_transport when running under OpenResty
-- (context.connector.connection_type == "embedded" - see
-- server/workers/observe_pending_worker.lua's own embedded_provider), or nil
-- (the vendored `webscraper` rock's own blocking LuaSocket default,
-- harmless in a plain process) otherwise. Guarded by pcall rather than
-- branching on connection_type alone, so a consumer that sets
-- connection_type == "embedded" without actually having lua-resty-http
-- installed degrades to the blocking default (with a logged warning)
-- instead of failing plugin setup outright.
local function build_scraper_transport(context)
	if not (context.connector and context.connector.connection_type == "embedded") then
		return nil
	end
	local ok, resty_transport = pcall(require, "watchtower_observer_web_scraper.resty_transport")
	if not ok then
		if context.logger then
			context.logger.warn(
				"watchtower_observer_web_scraper.plugin: resty transport unavailable, falling back to blocking fetch: "
					.. tostring(resty_transport)
			)
		end
		return nil
	end
	return resty_transport.new({})
end

function Plugin.setup(context)
	local connector = context.connector
	if not connector then
		error("watchtower_observer_web_scraper.plugin: context.connector is required")
	end

	local scraper_transport = build_scraper_transport(context)
	local fetch_remote_sites, observer_config_test_poller_deps = build_observer_config_deps(connector)
	observer_config_test_poller_deps.scraper_transport = scraper_transport

	-- Registers explicitly into THIS build's own registry (see
	-- watchtower_worker_core.lifecycle.build/observer_registry.new_type_registry)
	-- rather than watchtower_worker_core.observer_registry's module-global
	-- self-registration table - this plugin's setup() is the one place
	-- "web_scraper" ever gets registered.
	context.observer_types:register_type("web_scraper", web_scraper_observer.new)

	-- Independent of the "observer" role/config.observer.observe.enabled -
	-- see watchtower_worker_core.runner's config.observer.test_poll header
	-- comment for why this task has always been (and stays) role-independent,
	-- and why disabling it must never disable the "web_scraper" observer-type
	-- registration or observer_deps above, which real observing still needs.
	local test_poll_config = context.config.observer and context.config.observer.test_poll or {}
	local test_poll_enabled = test_poll_config.enabled ~= false

	local tasks = {}
	if test_poll_enabled then
		tasks[1] = {
			-- Unrelated to scheduler_tasks/jobs, but still included in
			-- Lifecycle:run_once (no `once = false`, so the default applies) so
			-- a one-shot/cron pass can service a request the UI already queued
			-- rather than leaving it stranded until a persistent worker happens
			-- to be running. observer_config_test_poller.poll_and_run's own
			-- return (true = a pending request was found and handled, false =
			-- nothing was pending) is propagated as `more`, the same idiom
			-- do_run_interval_observe uses for its own one-shot drain
			-- (shared/watchtower_worker_core/processors.lua): run_once's own
			-- `attempt()` repeats this task while `more` is true, so a single
			-- `--once` pass drains every currently pending request, not just
			-- the oldest one, and stops (false) once the queue is empty - no
			-- risk of spinning forever. Under the persistent loop, `more=true`
			-- simply means "due again immediately" rather than waiting a full
			-- interval, so a backlog drains promptly there too.
			name = "observer_config_test_poll",
			-- Its own dedicated cadence (config.observer.test_poll.interval),
			-- falling back to the shared root interval when unset - same
			-- "own interval, defaulting to the shared one" pattern every role's
			-- own <role>.interval already follows (watchtower_worker_core.runner's
			-- role_interval), letting this task run on a different cadence
			-- than the main observe/analyze/evaluate/deliver flow even from the
			-- same worker process (see docs/dev/worker-configuration.md).
			interval = test_poll_config.interval or context.config.interval,
			run = function()
				local ok, more =
					pcall(observer_config_test_poller.poll_and_run, observer_config_test_poller_deps, context.logger)
				if not ok then
					context.logger.warn("observer_config_test_poll: poll failed: " .. tostring(more))
					return false
				end
				return true, more
			end,
		}
	end

	return {
		observer_deps = {
			fetch_remote_sites = fetch_remote_sites,
			scraper_transport = scraper_transport,
			logger = context.logger,
		},
		tasks = tasks,
	}
end

return Plugin
