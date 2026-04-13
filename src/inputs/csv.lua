local csv = require("lua-csv/csv")
local transform_rename_json = require("lib.rename_json")
local take1 = require("lib.utils").take1

local map_value = {
	number = tonumber,
	bool = function(value)
		return value == "true"
	end,
	__include__ = true,
}

local function input_csv(options, wrap_ctx)
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

return take1(input_csv, function()
	return { file_read = false }
end)
