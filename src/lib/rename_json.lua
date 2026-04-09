local function transform_rename_json(options, item)
	local map = options and options.rename

	for k, v in pairs(map) do
		local rename_key = v
		local keyname = k
		item[rename_key] = item[keyname]
		item[keyname] = nil
	end

	return item
end

return transform_rename_json
