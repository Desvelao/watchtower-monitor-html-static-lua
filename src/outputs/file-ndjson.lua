--[[
Configuration:

file <string> define the file to append the data
fields? <string[]> define the fields to include in the output
order? <strin[]> define the key order to encode the JSON data

]]

local dkjson = require("dkjson")
local add_entry_on_file = require("lib.utils").add_entry_on_file
local table_select_fields = require("lib.table").table_select_fields

-- Splits a string using the specified delimiter.
local function split(str, delimiter)
	local result = {}
	for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
		table.insert(result, match)
	end
	return result
end

function file_ndjson(options, ctx)
	local file = options and options.file
	local final_ctx = ctx
	if not file then
		error("no file defined")
	end

	if options and options.fields then
		final_ctx = table_select_fields(ctx, options.fields)
	end

	add_entry_on_file(file, dkjson.encode(final_ctx, { keyorder = options.order }))

	return ctx
end

return file_ndjson
