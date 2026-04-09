-- Helper function to set a nested value in a table.
local function table_set_nested_field(target, keys, value)
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
local function table_select_fields(t, fields)
	local result = {}

	for i = 1, #fields do
		local fieldPath = fields[i]

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

			-- If the complete path exists,
			-- and set the nested value in the result table.
			if exists then
				table_set_nested_field(result, keys, value)
			end
		end
	end

	return result
end

-- A simple function to print tables recursively.
local function table_print(t, indent)
	indent = indent or ""
	for k, v in pairs(t) do
		if type(v) == "table" then
			print(indent .. tostring(k) .. ":")
			table_print(v, indent .. "  ")
		else
			print(indent .. tostring(k) .. ": " .. tostring(v))
		end
	end
end

local function get_keys_for_property_path(path)
	local keys = {}

	-- Split the path by dots
	for key in string.gmatch(path, "[^%.]+") do
		table.insert(keys, key)
	end

	return keys
end

-- Function to set a nested value using dot-notation path (e.g. "user.profile.name").
local function table_set_by_path(t, path, value)
	local keys = get_keys_for_property_path(path)

	if #keys == 0 then
		return
	end

	table_set_nested_field(t, keys, value)
end

local function table_get_by_path(tbl, path)
	local keys = get_keys_for_property_path(path)

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

return {
	table_print = table_print,
	table_select_fields = table_select_fields,
	table_set_by_path = table_set_by_path,
	table_get_by_path = table_get_by_path,
}
