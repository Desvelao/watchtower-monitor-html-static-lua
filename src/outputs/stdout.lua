-- Define the interpolation function
function interpolate(template, env)
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

function output_stdout(options, data)
	if not options.template then
		error("Template message was not defined.")
	end

	print(interpolate(options.template, { data = data }))

	return data
end

return output_stdout
