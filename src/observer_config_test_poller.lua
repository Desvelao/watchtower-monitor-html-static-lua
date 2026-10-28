-- The ad-hoc "test this observer config against a URL" poller for
-- plugins/observer_configs' own observer_config_test_requests/
-- type='observer_test' async test flow (see that plugin's header comment).
--
-- `deps` supplies the transport each runtime already has for talking to
-- the observer_config_test_requests/jobs tables - HTTP for the standalone
-- worker, direct DB/model access for the embedded one:
--   fetch_pending()                          -> {id, config, test_url} | nil, err
--   get_observer_config(id)                  -> {name, fields, mechanism_config} | nil [, err]   (mode "saved")
--   list_observer_config_targets(observable_type_id)
--                                             -> rows | nil, err      (mode "all"; generic
--                                                {name, fields, mechanism_config} rows, e.g. via
--                                                GET /api/observer_configs/targets - reshaped
--                                                to scraper_creator's `sites` shape here)
--   report_triggering(id)                    -> ok, err
--   report_result(id, result)                -> ok, err   -- result = {ok=bool, data=table|nil}
--   report_error(id, message)                -> ok, err
--   scraper_transport (optional)             - passed straight through to
--     scraper_creator.new's own `transport` param
local scraper_creator = require("watchtower_observer_web_scraper.scraper_creator")

local M = {}

-- Reshapes a {name, fields, mechanism_config} row (an observer_configs row
-- decoded, or an ad-hoc test's own request fields) into the
-- scraper_creator.new `sites` entry shape. The server hands out generic
-- observer_configs rows and knows nothing about this observer type, so the
-- reshaping lives here (also used by plugin.lua for remote sites).
local function to_site(name, fields, mechanism_config)
	mechanism_config = mechanism_config or {}
	return {
		name = name,
		urls_match = mechanism_config.urls_match,
		fields = fields,
		expect_selector = mechanism_config.expect_selector,
		block_selector = mechanism_config.block_selector,
		block_text = mechanism_config.block_text,
		headers = mechanism_config.headers,
		ssl_verify = mechanism_config.ssl_verify,
	}
end

M.to_site = to_site

-- Resolves the `sites` (for scraper_creator.new) a test request's config
-- needs, per config.mode (see server/dataset/schema.sql's comment on
-- observer_config_test_requests). Raises on an unknown mode or a missing
-- observer config.
function M.resolve_sites(test_config, source)
	if test_config.mode == "adhoc" then
		return { to_site(test_config.name, test_config.fields, test_config.mechanism_config) }
	elseif test_config.mode == "saved" then
		local row, err = source.get_observer_config(test_config.observer_config_id)
		if not row then
			error(err or ("observer config not found: " .. tostring(test_config.observer_config_id)))
		end
		return { to_site(row.name, row.fields, row.mechanism_config) }
	elseif test_config.mode == "all" then
		local rows, err = source.list_observer_config_targets(test_config.observable_type_id)
		if not rows then
			error(err or "failed to fetch observer config targets")
		end
		local sites = {}
		for i, row in ipairs(rows) do
			sites[i] = to_site(row.name, row.fields, row.mechanism_config)
		end
		return sites
	end
	error("unknown test request mode: " .. tostring(test_config.mode))
end

-- Returns true if a pending request was found (and handled, regardless of
-- the scrape's own outcome), false if there was nothing pending.
function M.poll_and_run(deps, logger)
	local request, fetch_err = deps.fetch_pending()
	if not request then
		if fetch_err then
			logger.warn("observer_config_test_poller: fetch_pending failed: " .. tostring(fetch_err))
		end
		return false
	end

	local triggering_ok, triggering_err = deps.report_triggering(request.id)
	if not triggering_ok then
		logger.warn(
			"observer_config_test_poller: failed to report triggering for request "
				.. tostring(request.id)
				.. ": "
				.. tostring(triggering_err)
		)
		return true
	end

	local function finish(report, ...)
		local ok, err = report(request.id, ...)
		if not ok then
			logger.warn(
				"observer_config_test_poller: failed to report outcome for request "
					.. tostring(request.id)
					.. ": "
					.. tostring(err)
			)
		end
		return true
	end

	local resolve_ok, sites_or_err = pcall(M.resolve_sites, request.config, deps)
	if not resolve_ok then
		return finish(deps.report_error, tostring(sites_or_err))
	end
	if not sites_or_err then
		return finish(deps.report_error, "no sites resolved for this request")
	end

	local webscraper = scraper_creator.new(sites_or_err, deps.scraper_transport, logger)

	local ran_ok, data, run_err = pcall(function()
		return webscraper:run(request.test_url)
	end)

	if not ran_ok then
		return finish(deps.report_error, tostring(data))
	end

	return finish(deps.report_result, { ok = (data and run_err == nil) and true or false, data = data or nil })
end

return M
