local csv = require("lua-csv/csv")
local transform_rename_json = require("lib.rename_json")

--[[
Configuration:

file <string> define the file to load the data
columns <{ [key:string]: number|boolean }> define the columns to extract and the formatter to use
header? <boolean> define the usage of headers in the file
rename <{ [key:string: string]}> rename the field

]]

local map_value = {
	number = tonumber,
	bool = function(value)
		return value == "true"
	end,
	__include__ = true,
}

function input_csv(options, wrap_ctx)
	if wrap_ctx.file_read then
		return nil
	end

	local file = options and options.file
	local map = options and options.columns
	local header = options and options.header

	if not file then
		error("File is required")
	end

	if not map and not header then
		error("headers or columns are required")
	end

	local columns = nil

	if map then
		for k, v in pairs(map) do
			local formatvalue, keyname

			if type(v) == "table" then
				if v.include then
					formatvalue = "__include__"
				else
					formatvalue = v.format
				end
				if v.map ~= nil then
					keyname = v.map
				else
					keyname = k
				end
			else
				formatvalue = v
				keyname = k
			end
			if not columns then
				columns = {}
			end
			columns[keyname] = map_value[formatvalue]
		end
	end

	local f = csv.open(file, {
		header = options and options.header,
		columns = columns,
	})

	wrap_ctx.file_read = true

	local items = {}
	for line in f:lines() do
		local item = line
		if options.rename then
			item = transform_rename_json(options, item)
		end
		table.insert(items, item)
	end

	return items
end

local function take1(fn, get_init)
	return function()
		local wrap_ctx = get_init and get_init() or nil
		local items = {}
		local item_returned = 0

		local function return_item()
			item_returned = item_returned + 1
			return table.remove(items, 1)
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

return take1(input_csv, function()
	return { file_read = false }
end)
