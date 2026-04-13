-- parser deep limit
local dkjson = require("dkjson")
local WebScraper = require("webscraper").WebScraper
local WebScraperFilters = require("webscraper").Filters
local WebScraperValidators = require("webscraper").Validators
local requests = require("requests")
local dkjson = require("dkjson")

local function load_from_api(url)
	if not url then
		error("url was not provided")
	end

	-- Setup web scraper with remote sites
	local sites = {}
	local size = 1
	local from = 0
	local from_prev = 0
	while true do
		local request_url = url .. "?from=" .. tostring(from) .. "&size=" .. tostring(size)
		local response = requests.get({ request_url, { headers = { ["Accept"] = "application/json" } } })
		local body = dkjson.decode(response.text)
		local items = body.items
		from = from + #items

		for _, item in ipairs(items) do
			table.insert(sites, item)
		end

		if from >= body.total_items or from_prev == from then
			break
		end
		from_prev = from
	end

	return sites
end

return function(options, event, ctx, utils)
	local webscraper
	if ctx.cache and ctx.cache:has("scraper") then
		webscraper = ctx.cache:get("scraper")
	else
		webscraper = WebScraper:new()
		webscraper.logger.debug = function(msg) end

		for k, v in pairs(WebScraperFilters) do
			webscraper.filters:register(k, v)
		end

		for k, v in pairs(WebScraperValidators) do
			webscraper.validators:register(k, v)
		end

		if options.sites then
			for _, site in ipairs(options.sites) do
				if site.url then
					local sites = load_from_api(site.url)
					for __, v in ipairs(sites) do
						webscraper.sites:register(v.name, v)
					end
				else
					webscraper.sites:register(site.name, site)
				end
			end
		end

		ctx.cache:set("scraper", webscraper)
	end

	if webscraper.sites.size == 0 then
		error("there are not sites defined")
	end

	local extracted_data = webscraper:run(event.data.url)
	if extracted_data then
		for k, v in pairs(extracted_data) do
			event.data[k] = v
		end
	end

	return event
end
