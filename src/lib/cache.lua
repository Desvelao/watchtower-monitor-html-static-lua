local Cache = {}

function Cache:new()
	local instance = {
		_data = {},
	}
	setmetatable(instance, { __index = Cache })
	return instance
end

function Cache:get(key)
	return self._data[key]
end

function Cache:set(key, value)
	self._data[key] = value
	return self._data[key]
end

function Cache:has(key)
	return self._data[key] ~= nil
end

return Cache
