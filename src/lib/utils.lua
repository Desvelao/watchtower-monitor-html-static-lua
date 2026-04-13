local function get_modules_in_directory(directory)
	local modules = {}
	local p = io.popen("ls " .. directory)
	for file in p:lines() do
		if file:match("%.lua$") then
			local moduleName = file:gsub("%.lua$", "")
			local modulePath = directory .. "." .. moduleName
			table.insert(modules, { modulePath, moduleName })
		end
	end
	p:close()
	return modules
end

local function require_modules_in_directory(directory)
	local modules = get_modules_in_directory(directory)
	local result = {}
	for _, mod in ipairs(modules) do
		result[mod[2]] = require(mod[1])
	end
	return result
end

local function add_entry_on_file(file, data)
	local f = io.open(file, "a")
	f:write(data .. "\n")
	f:close()
end

local function take1(fn, get_init)
	return function()
		local wrap_ctx = get_init and get_init() or nil
		local items = {}

		local function return_item()
			local item = table.remove(items, 1)
			return item ~= nil, item
		end

		return function(...)
			if items ~= nil and #items > 0 then
				return return_item()
			end

			items = fn(unpack({ ... }), wrap_ctx)

			if items ~= nil and #items > 0 then
				return return_item()
			end

			return items
		end
	end
end

return {
	get_modules_in_directory = get_modules_in_directory,
	require_modules_in_directory = require_modules_in_directory,
	add_entry_on_file = add_entry_on_file,
	take1 = take1,
}
