local dkjson = require("dkjson")

-- Helper function to set a nested value in a table.
local function set_nested_field(target, keys, value)
	local current = target
	for i = 1, #keys - 1 do
		local key = keys[i]
		-- Create a new table if not present or if the current value is not already a table.
		if type(current[key]) ~= "table" then
			current[key] = {}
		end
		current = current[key]
	end
	current[keys[#keys]] = value
end

-- Function to select fields from a table with optional value formatting.
-- The `fields` parameter is an array where each element is either:
--   - A string representing the dot-delimited field path (e.g. "user.name")
--   - A table with at least a "field" key and optionally a "format" function.
local function select_formatted_fields(t, fields, get_formatter)
	local result = {}

	for i = 1, #fields do
		local fieldSpec = fields[i]
		local fieldPath, formatter, formatter_script

		if type(fieldSpec) == "string" then
			fieldPath = fieldSpec
			formatter = nil
		elseif type(fieldSpec) == "table" then
			fieldPath = fieldSpec.field
			formatter = fieldSpec.format
			formatter_script = fieldSpec.format_script
		end

		-- Only proceed if fieldPath is defined.
		if fieldPath then
			-- Split the dot-delimited field path into keys.
			local keys = {}
			for key in string.gmatch(fieldPath, "[^%.]+") do
				table.insert(keys, key)
			end

			-- Traverse the source table using the keys.
			local value = t
			local exists = true
			for j = 1, #keys do
				local key = keys[j]
				if type(value) == "table" then
					value = value[key]
				else
					exists = false
					break
				end
				if value == nil then
					exists = false
					break
				end
			end

			-- If the complete path exists, apply formatting if provided
			-- and set the nested value in the result table.
			if exists then
				if formatter then
					if type(formatter) == "function" then
						value = get_formatter("function")(value, { value = value, ctx = t, env = _G })
					elseif type(formatter) == "string" then
						value = get_formatter(formatter)(value, { value = value, ctx = t, env = _G })
					end
				elseif formatter_script then
					value = get_formatter("script")(formatter_script, { value = value, ctx = t, env = _G })
				end

				set_nested_field(result, keys, value)
			else
				if type(fieldSpec.default) ~= nil then
					value = fieldSpec.default
				elseif formatter_script then
					value = get_formatter("script")(formatter_script, { value = value, ctx = t, env = _G })
				else
					value = dkjson.null
				end
				set_nested_field(result, keys, value)
			end
		end
	end

	return result
end

-- A simple function to print tables recursively.
local function print_table(t, indent)
	indent = indent or ""
	for k, v in pairs(t) do
		if type(v) == "table" then
			print(indent .. tostring(k) .. ":")
			print_table(v, indent .. "  ")
		else
			print(indent .. tostring(k) .. ": " .. tostring(v))
		end
	end
end

local formatters = {
	number = function(v)
		return tonumber(v)
	end,
	string = function(v)
		return tostring(v)
	end,
	boolean = function(v)
		if v then
			return true
		else
			return false
		end
	end,
	["function"] = function(f, ...)
		return f(...)
	end,
	script = function(...)
		return utils.evaluate(...)
	end,
}

local function get_formatter(value)
	return formatters[value] or formatters.script
end

function normalize_json(options, ctx, _, utils)
	if not options.fields then
		error("fields are not defined")
	end

	local r = select_formatted_fields(ctx, options.fields, get_formatter)

	return r
end

return normalize_json
