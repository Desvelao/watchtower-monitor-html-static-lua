-- Builds a WebScraper instance with all filters/validators registered and
-- every entry in `sites` (an array of {name, urls_match, fields, urls_test,
-- headers}) registered as a scrapeable site - shared by both
-- plugins/observer_configs (server-side ad-hoc tests, see that plugin's own
-- use of this module) and the workers (real scheduled scrapes, see
-- watchtower_worker_core.processors' scrape_observable).
local M = {}

local function build_page_config(site)
	return {
		expect_selector = site.expect_selector,
		block_selector = site.block_selector,
		block_text = site.block_text,
	}
end

-- Mirrors the same global the plugin sets before ever calling WebScraper -
-- the underlying htmlparser needs this raised above its small default for
-- real-world pages. A global (not local) because htmlparser reads it as a
-- bare global itself; setting it here means every caller of this module
-- gets the same deep-parse limit without duplicating the assignment.
htmlparser_looplimit = 8000

-- Returns (webscraper, capabilities) - capabilities is the sorted,
-- de-duplicated set of configured site names, self-reported in worker
-- heartbeats so an operator can see which sites a given worker actually
-- knows how to scrape.
--
-- `transport` (optional) overrides the WebScraper instance's own `_fetch`
-- method (mirroring watchtower_worker_core.notification_senders's transport DI) -
-- WebScraper:new() returns a plain table with no constructor args/seam, so
-- this shadows `_fetch` on the instance itself rather than the shared
-- WebScraper table, leaving every other caller (which passes no transport)
-- completely unaffected. Needed because the vendored rock's own default
-- `_fetch` is a blocking LuaSocket/LuaSec call, unsafe inside an nginx
-- worker process - see this package's own resty_transport.lua header
-- comment for the full rationale (same class of bug already fixed for
-- outbound notifications), and plugin.lua's build_scraper_transport for
-- where the `transport` passed in here actually gets picked.
--
-- `logger` (optional) overrides the instance's own `self.logger` the same
-- way - the vendored rock's own WebScraper:new() hardcodes a
-- create_log_tag/print("[TAG] message") logger with no constructor seam for
-- it, which doesn't match watchtower_worker_core.logger's
-- "[timestamp] [LEVEL] [tag] message" format/LOG_LEVEL gating used
-- everywhere else in the worker pipeline. `self.logger` is a plain table
-- read fresh at the top of every method that logs, so it's exactly as safe
-- to shadow post-construction as `_fetch` above.
function M.new(sites, transport, logger)
	local WebScraper = require("webscraper").WebScraper
	local WebScraperFilters = require("webscraper.filters.filters")
	local WebScraperValidators = require("webscraper.filters.validators")

	local webscraper = WebScraper:new()
	if transport then
		webscraper._fetch = function(_, url, headers, ssl_verify)
			return transport:fetch(url, headers, ssl_verify)
		end
	end
	if logger then
		webscraper.logger = logger
	end
	for k, v in pairs(WebScraperFilters) do
		webscraper.filters:register(k, v)
	end
	for k, v in pairs(WebScraperValidators) do
		webscraper.validators:register(k, v)
	end

	local capabilities = {}
	for _, site in ipairs(sites or {}) do
		webscraper.sites:register(site.name, {
			name = site.name,
			urls_match = site.urls_match,
			fields = site.fields,
			page = build_page_config(site),
			headers = site.headers,
			ssl_verify = site.ssl_verify,
		})
		table.insert(capabilities, site.name)
	end
	table.sort(capabilities)

	return webscraper, capabilities
end

return M
