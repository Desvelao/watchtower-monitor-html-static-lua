-- The "web_scraper" observer type: wraps
-- watchtower_observer_web_scraper.scraper_creator's WebScraper (unchanged -
-- it's already fully generic over whatever `fields` keys a site declares)
-- and reshapes its raw, always-string field extraction into a `properties`
-- table shaped for the Observable's observable type's observation_schema,
-- coerced to that schema's declared types.
local scraper_creator = require("watchtower_observer_web_scraper.scraper_creator")
local Logger = require("watchtower_worker_core.logger")
local cjson_safe = require("cjson.safe")

local M = {}

local logger = Logger.new("web_scraper")

-- Only meaningful for sites_source="remote" (see M.new below) - how often
-- (seconds) a "remote" instance re-fetches its site list from
-- deps.fetch_remote_sites() as part of its own :run, when an
-- observer_config doesn't set its own remote_sites_refresh_interval. This
-- is entirely internal to this one observer type - no other observer type
-- has this concept, so it deliberately doesn't live in
-- watchtower_worker_core.observer_registry or runner.build_config.
local DEFAULT_REMOTE_SITES_REFRESH_INTERVAL = 60

-- The safe-to-report subset of an observer_config's own fields - see
-- M:reportable_config below.
local SITE_SAFE_FIELDS = { "name", "urls_match", "fields", "urls_test" }
local OBSERVER_SAFE_FIELDS = { "id", "type", "observable_type", "url_property", "sites_source", "ndjson_output" }

local function pick(tbl, keys)
	if type(tbl) ~= "table" then
		return nil
	end
	local result = {}
	for _, key in ipairs(keys) do
		if tbl[key] ~= nil then
			result[key] = tbl[key]
		end
	end
	return result
end

-- observer_config: { id, type="web_scraper", observable_type, url_property = "url" (default),
--                    sites_source = "local" (default) | "remote", sites = {...},
--                    remote_sites_refresh_interval = 60 (default, sites_source="remote" only) }
--
-- sites_source="local" (default): `sites` is read directly off
-- observer_config, same as before - a static list baked into
-- WORKER_CONFIG_FILE, never refreshed.
-- sites_source="remote": `sites` is fetched here, via
-- deps.fetch_remote_sites(observer_config) - a function supplied by
-- whichever worker entry point builds the registry, given this instance's
-- own observer_config so more than one "remote" instance can coexist in the
-- same registry (standalone: an HTTP GET against /api/observer_configs/targets;
-- embedded: a direct models.ObserverConfigs:select()) - letting an operator
-- manage scraper site definitions centrally on the server instead of
-- keeping a copy embedded in every worker's local config. A fetch failure
-- here (at
-- construction) raises, matching observer_registry.new's own
-- construction-time-failure philosophy - a caller that wants to fall back
-- rather than fail construction catches this itself, see
-- watchtower_worker_core.lifecycle's build (which falls back to an empty registry).
-- Once constructed, a "remote" instance keeps its own site list fresh by
-- re-fetching it as part of :run (see below) rather than needing an
-- external rebuild - so unlike construction, a later refresh failure never
-- raises, it just logs and keeps scraping with the last-known-good sites.
function M.new(observer_config, deps)
	local sites
	if observer_config.sites_source == "remote" then
		if not (deps and deps.fetch_remote_sites) then
			error("web_scraper: sites_source='remote' requires deps.fetch_remote_sites")
		end
		local remote_sites, err = deps.fetch_remote_sites(observer_config)
		if not remote_sites then
			error("web_scraper: failed to fetch remote sites: " .. tostring(err))
		end
		sites = remote_sites
	else
		sites = observer_config.sites or {}
	end

	local webscraper, capabilities =
		scraper_creator.new(sites, deps and deps.scraper_transport, (deps and deps.logger) or logger)

	local instance = {
		_webscraper = webscraper,
		_capabilities = capabilities,
		_url_property = observer_config.url_property or "url",
		_observer_id = observer_config.id,
		_ndjson_output = observer_config.ndjson_output,
	}

	if observer_config.sites_source == "remote" then
		instance._sites_source = "remote"
		instance._deps = deps
		instance._observer_config = observer_config
		instance._refresh_interval = observer_config.remote_sites_refresh_interval
			or DEFAULT_REMOTE_SITES_REFRESH_INTERVAL
		instance._refreshing = false
	end

	return setmetatable(instance, { __index = M })
end

function M:capabilities()
	return self._capabilities
end

-- The safe-to-report subset of this observer's own config, for heartbeat
-- self-reporting (config.report_config) - called by
-- watchtower_worker_core.observer_registry's :reportable_observers(), the
-- same optional-instance-method interface :capabilities() above uses, no
-- separate self-registration of any kind.
function M:reportable_config(observer_config)
	local picked = pick(observer_config, OBSERVER_SAFE_FIELDS)
	if observer_config.sites then
		local sites = {}
		for _, site in ipairs(observer_config.sites) do
			table.insert(sites, pick(site, SITE_SAFE_FIELDS))
		end
		picked.sites = sites
	end
	return picked
end

-- Coerces a raw (always-string) WebScraper field into `prop_type`'s Lua
-- representation. Critical for "boolean": server/lib/property_schema.lua's
-- validate_scalar hard-rejects a string for a boolean-typed property
-- (`type(value) ~= "boolean"`) - unlike "number", which that same
-- validator already tonumber()s server-side - so a real Lua boolean must
-- be produced here, before these properties are ever POSTed/validated,
-- not left as a string for the server to loosely interpret.
local TRUTHY = { ["true"] = true, ["1"] = true, ["yes"] = true }
local FALSY = { ["false"] = true, ["0"] = true, ["no"] = true }

local function coerce(prop_type, raw)
	if raw == nil then
		return nil
	end
	if prop_type == "number" then
		return tonumber(raw)
	end
	if prop_type == "boolean" then
		local normalized = tostring(raw):lower():match("^%s*(.-)%s*$")
		if TRUTHY[normalized] then
			return true
		end
		if FALSY[normalized] then
			return false
		end
		return nil
	end
	return raw -- string/url/date/enum: WebScraper already returns a string
end

-- Re-fetches this instance's site list from deps.fetch_remote_sites() and
-- swaps in a freshly-built WebScraper/capabilities. A no-op for a
-- sites_source="local" instance (self._sites_source is nil, so this simply
-- returns immediately).
--
-- Called by this instance's own :maintenance_tasks() entry below, on its
-- own self._refresh_interval schedule - watchtower_worker_core.lifecycle
-- aggregates it (via observer_registry:maintenance_tasks()) into the
-- worker's ordinary task list, so a "remote" instance's site list stays
-- current without ever needing a worker restart, scoped to exactly this one
-- observer/observable type and nothing else, and independent of whether
-- this observable type is actually being scraped right now.
--
-- self._refreshing guards two concurrent refresh attempts (possible under
-- OpenResty's embedded worker, where this task's own ngx.timer.every
-- callback can start on a new light thread before a previous one's
-- yielding fetch has finished, or if a "remote" instance's :run is ever
-- called concurrently with its own refresh - not possible for the
-- standalone worker's single-threaded loop.lua, but harmless to check
-- there too): it's set synchronously, before the fetch's own yield point,
-- so OpenResty's cooperative scheduling makes the check-and-set itself
-- race-free without any extra locking. A second concurrent call just sees
-- refreshing=true and skips its own attempt.
--
-- A failed fetch/build logs and leaves self._webscraper/self._capabilities
-- untouched (never raises - unlike M.new's construction-time fetch, this
-- must not break scraping).
function M:_refresh_remote_sites()
	if self._sites_source ~= "remote" or self._refreshing then
		return true
	end

	self._refreshing = true
	local ok, remote_sites_or_err = pcall(self._deps.fetch_remote_sites, self._observer_config)
	if ok and remote_sites_or_err then
		local webscraper, capabilities = scraper_creator.new(
			remote_sites_or_err,
			self._deps and self._deps.scraper_transport,
			(self._deps and self._deps.logger) or logger
		)
		self._webscraper = webscraper
		self._capabilities = capabilities
	else
		logger.warn("refresh failed, keeping previous sites: " .. tostring(remote_sites_or_err))
	end
	self._refreshing = false
	return ok and remote_sites_or_err ~= nil
end

-- Optional instance method, aggregated generically by
-- observer_registry:maintenance_tasks() (mirroring :capabilities()/
-- :reportable_config() above) - a sites_source="remote" instance's own
-- periodic site-list refresh, registered as a real scheduled task rather
-- than checked inline on every :run. Empty for a sites_source="local"
-- instance (nothing to refresh).
function M:maintenance_tasks()
	if self._sites_source ~= "remote" then
		return {}
	end
	return {
		{
			name = "web_scraper_refresh_remote_sites:" .. tostring(self._observer_id),
			interval = self._refresh_interval,
			run = function()
				return self:_refresh_remote_sites()
			end,
		},
	}
end

-- Appends one JSON line per successful scrape to self._ndjson_output.file,
-- when an observer_config sets `ndjson_output = { file = "...", fields? =
-- {...} }` - an opt-in side-channel for consuming the same observation data
-- outside the watchtower server (e.g. a local audit trail), independent of
-- whatever the server itself does with the posted observation. `fields`
-- (optional) restricts the encoded `properties` to an allow-list; omitted,
-- every extracted property is written. Uses cjson.safe, the JSON library
-- already used throughout shared/watchtower_worker_core (not the old
-- pipeline's dkjson, which isn't a dependency here). A write failure (bad
-- path/permissions) only logs a warning - this is a side-channel, and must
-- never fail a real observe, mirroring _refresh_remote_sites's own
-- log-and-continue philosophy above.
local function write_ndjson_output(ndjson_output, observable, observable_type, properties)
	if not (ndjson_output and ndjson_output.file) then
		return
	end

	local output_properties = properties
	if ndjson_output.fields then
		output_properties = pick(properties, ndjson_output.fields)
	end

	local record = {
		observable_id = observable.id,
		observable_name = observable.name,
		observable_type = observable_type and observable_type.name,
		properties = output_properties,
		observed_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	}

	local encoded, encode_err = cjson_safe.encode(record)
	if not encoded then
		logger.warn("ndjson_output: failed to encode record: " .. tostring(encode_err))
		return
	end

	local f, open_err = io.open(ndjson_output.file, "a")
	if not f then
		logger.warn("ndjson_output: failed to open '" .. tostring(ndjson_output.file) .. "': " .. tostring(open_err))
		return
	end
	f:write(encoded, "\n")
	f:close()
end

-- Returns (properties, nil) | (nil, err). `properties` only contains keys
-- the observable type's observation_schema declares AND that the scrape
-- actually extracted+coerced successfully - an unmatched/uncoercible field
-- is simply absent, the same "absence not nil" semantics WebScraper itself
-- already has for a field whose selector didn't match (WebScraper also
-- pre-seeds its result's own `url` key to the input URL before per-field
-- extraction runs, so a scraped `url` observation property defaults to the
-- Observable's URL unless a site's own `fields.url` selector overrides it).
-- Returns (nil, err) if no registered site's urls_match matched the Observable's
-- URL, or if ANY observation_schema property marked `required` failed to
-- extract/coerce - generalizing today's "no price extracted = failure"
-- convention (price is the seeded "product" type's only required
-- observation field) to "no required field extracted = failure" for any
-- observable type.
function M:run(observable, observable_type)
	local url = observable.properties and observable.properties[self._url_property]
	if not url then
		return nil, string.format("observable has no '%s' property to scrape", self._url_property)
	end

	-- webscraper:run() now returns (result, run_err) - run_err set (a fetch
	-- failure, or a `page` validation failure - a blocked/CAPTCHA page, or a
	-- missing expected marker, see watchtower_observer_web_scraper.scraper_creator's
	-- page config) means the scrape ran but didn't succeed, distinct from
	-- `not ok` (a Lua error raised out of the call entirely). Surfacing
	-- run_err directly here turns a blocked page into a clear "page blocked:
	-- ..." error instead of the generic "required property not extracted"
	-- message below.
	local ok, result, run_err = pcall(function()
		return self._webscraper:run(url)
	end)
	if not ok then
		return nil, tostring(result)
	end
	if not result then
		return nil, "no registered site matched this observable's URL"
	end
	if run_err then
		return nil, run_err
	end

	local schema = (observable_type and observable_type.observation_schema) or {}
	local properties = {}
	for _, prop in ipairs(schema) do
		local coerced = coerce(prop.type, result[prop.name])
		if coerced ~= nil then
			properties[prop.name] = coerced
		elseif prop.required then
			return nil, string.format("scrape ran but required property '%s' was not extracted", prop.name)
		end
	end

	write_ndjson_output(self._ndjson_output, observable, observable_type, properties)

	return properties, nil
end

-- No self-registration here: a pure builder module, with no import-time
-- side effects. `M.new` is registered explicitly by whichever consumer
-- wants "web_scraper" available - watchtower_observer_web_scraper.plugin's
-- own setup() (context.observer_types:register_type("web_scraper", M.new)),
-- or watchtower_observer_web_scraper.init's M.new_registry facade for a
-- bare, non-lifecycle consumer. :capabilities()/:reportable_config()/
-- :maintenance_tasks() above are resolved generically by whatever
-- observer_registry instance ends up constructed either way, with no
-- separate registration of their own.
return M
