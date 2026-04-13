local requests = require("requests")
local take1 = require("lib.utils").take1

-- Define the interpolation function
local function interpolate(template, env)
	-- Use the provided environment, or default to the global environment.
	-- env = env or _G

	-- Allow access to global values if the key isn't found in 'env'
	-- setmetatable(env, { __index = _G })

	-- Replace every '{...}' expression in the template
	local result = template:gsub("{(.-)}", function(code)
		-- Prepend 'return' to evaluate the expression
		local chunk, err = loadstring("return " .. code)
		if not chunk then
			error("Interpolation error in expression {" .. code .. "}: " .. err)
		end

		-- Set the environment for the chunk for proper variable resolution
		setfenv(chunk, env)

		-- Execute the chunk safely
		local success, value = pcall(chunk)
		if not success then
			error("Error evaluating expression {" .. code .. "}: " .. tostring(value))
		end

		return tostring(value)
	end)

	return result
end

local function get_nested_property(tbl, path)
	local keys = {}

	-- Split the path by dots
	for key in string.gmatch(path, "[^%.]+") do
		table.insert(keys, key)
	end

	-- Traverse the table using keys
	local value = tbl
	for _, key in ipairs(keys) do
		if type(value) == "table" and value[key] ~= nil then
			value = value[key]
		else
			return nil -- Return nil if the path is invalid
		end
	end

	return value
end

local function ingester_api(options, wrap_ctx)
	if type(options) ~= "table" then
		error("options should be a table")
	end

	if wrap_ctx.total_items and wrap_ctx.total_items <= wrap_ctx.item_from then
		return nil
	end

	local url = interpolate(options.url, { wrap_ctx = wrap_ctx, options = options or {} })

	if not url then
		error("url is not defined")
	end

	local request_options = options.request_options
	local response = requests.get(url, request_options)

	local results = nil

	if options.map_response then
		response = options.map_response(response)
	elseif options.json then
		response = response.json()

		if options.json.items_path then
			local items = get_nested_property(response, options.json.items_path)

			if items and #items > 0 then
				wrap_ctx.item_from = wrap_ctx.item_from + #items
				wrap_ctx.total_items = get_nested_property(response, options.json.total_items_path)
				if options.json.item_map then
					results = {}
					for _, item in ipairs(items) do
						local item_map = {}
						for key, item_key_path in pairs(options.json.item_map) do
							item_map[key] = get_nested_property(item, item_key_path)
						end
						table.insert(results, item_map)
					end
				end
			else
				print("There are not items")
			end
		end
	end

	return results
end

return take1(ingester_api, function()
	return { item_from = 0, total_items = nil }
end)
