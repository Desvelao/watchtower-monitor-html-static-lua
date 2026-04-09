function get_modules_in_directory(directory)
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

function require_modules_in_directory(directory)
	local modules = get_modules_in_directory(directory)
	local result = {}
	for _, mod in ipairs(modules) do
		result[mod[2]] = require(mod[1])
	end
	return result
end

function add_entry_on_file(file, data)
	local f = io.open(file, "a")
	f:write(data .. "\n")
	f:close()
end

return {
	get_modules_in_directory = get_modules_in_directory,
	require_modules_in_directory = require_modules_in_directory,
	add_entry_on_file = add_entry_on_file,
}
