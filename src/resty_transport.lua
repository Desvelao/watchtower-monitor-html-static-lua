-- OpenResty-native counterpart to the vendored `webscraper` LuaRocks
-- package's own default WebScraper:_fetch (see
-- web_scraper/web_scraper.lua in github.com/Desvelao/webscrapper),
-- which is built on lua-requests (LuaSocket/LuaSec) - that's a real,
-- blocking OS socket call, fine for the standalone worker (a plain Lua 5.1
-- process, no nginx) but not safe inside an nginx worker process: it would
-- stall that worker's single-threaded event loop for the duration of every
-- scrape's HTTP fetch, stalling API request handling running in the same
-- process the whole time (see watchtower-server's own
-- server/workers/observe_pending_worker.lua, USE_EMBED_WORKER=1) - the exact
-- same class of bug watchtower-server's server/lib/resty_webhook_transport.lua
-- already fixed for outbound notifications. lua-resty-http is the
-- cosocket-based (ngx.socket.tcp) client OpenResty apps use instead.
--
-- Lives inside this package (rather than being injected by a consumer, the
-- way notification_senders' transport seam still works) because it has no
-- watchtower-server-specific dependencies of its own - just `resty.http`, a
-- plain OpenResty API. `watchtower_observer_web_scraper.plugin` requires it
-- itself, guarded by `pcall` so a consumer running outside OpenResty (e.g.
-- the standalone worker's plain Lua 5.1 process) degrades safely to
-- scraper_creator's vendored-rock blocking default instead of failing to
-- load - see that module's `build_scraper_transport`.
--
-- Duck-types WebScraper:_fetch(self, url) -> (ok, text, response) exactly -
-- see WebScraper:_run's use of it in the vendored package - so it's
-- injected as an instance-level override (shadowing the metatable method)
-- only when selected, via watchtower_observer_web_scraper.scraper_creator's
-- optional `transport` parameter.
--
-- Deliberately omits `Accept-Encoding: gzip` (unlike the vendored rock's
-- own default _fetch), so it never needs to replicate that function's
-- zlib.inflate() decompression step - an accepted, documented minor
-- behavioral difference: most sites respond uncompressed when no
-- Accept-Encoding header is sent at all.
local http = require("resty.http")

-- Sent with every request unless overridden via M.new(opts) - mirrors the
-- vendored `webscraper` LuaRocks package's own DEFAULT_HEADERS (see
-- WebScraper:new()'s doc comment there), duplicated here because this
-- transport bypasses that package's own _fetch/headers entirely (see the
-- header comment above). No previous default existed at all (just Accept),
-- a bigger giveaway to anti-bot/anti-scraping systems than a real browser
-- User-Agent.
local DEFAULT_HEADERS = {
	["Accept"] = "text/html",
	["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
}

local M = {}

-- opts.headers (optional) merges on top of DEFAULT_HEADERS, letting a
-- caller override the User-Agent or add other headers.
function M.new(opts)
	opts = opts or {}
	local headers = {}
	for k, v in pairs(DEFAULT_HEADERS) do
		headers[k] = v
	end
	if opts.headers then
		for k, v in pairs(opts.headers) do
			headers[k] = v
		end
	end
	return setmetatable({ timeout_ms = (opts.timeout or 15) * 1000, headers = headers }, { __index = M })
end

-- `headers` (optional) is a per-site override merged on top of self.headers
-- for this one call only - self.headers itself is never mutated, since
-- it's shared across every site this transport instance serves.
-- `ssl_verify` (optional, an observer_configs.mechanism_config.ssl_verify
-- value): only
-- `false` disables certificate verification for this one request; nil/true
-- both mean "verify normally" - an escape hatch for a target whose
-- certificate chain roots to a CA this container's trust store doesn't
-- have (see server/dataset/schema.sql's column comment), as an alternative
-- to patching that trust store.
function M:fetch(url, headers, ssl_verify)
	local request_headers = self.headers
	if headers then
		request_headers = {}
		for k, v in pairs(self.headers) do
			request_headers[k] = v
		end
		for k, v in pairs(headers) do
			request_headers[k] = v
		end
	end

	local httpc = http.new()
	httpc:set_timeout(self.timeout_ms)
	local res, err = httpc:request_uri(url, {
		method = "GET",
		headers = request_headers,
		ssl_verify = ssl_verify ~= false,
	})
	if not res then
		ngx.log(ngx.ERR, string.format("scrape fetch of %s failed: %s", url, tostring(err)))
		return false, nil, { status_code = 0, headers = {} }
	end
	return res.status == 200, res.body, { status_code = res.status, headers = res.headers }
end

return M
