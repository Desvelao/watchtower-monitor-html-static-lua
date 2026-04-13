--[[
Configuration:

webhook_url <string> define Discord webhook URL

]]

local requests = require("requests")
local dkjson = require("dkjson")

local function webhook(options, data, env, utils)
	local method = options and options.method or "post"
	local url = options and options.url
	local payload_script = options and options.payload_script
	local headers = options and options.headers or { ["Content-Type"] = "application/json" }
	local payload_encoding = options and options.payload_encoding or "json"

	if not url then
		error("url is not defined")
	end

	if not payload_script then
		error("script is not defined")
	end

	if requests[method] == nil then
		error(string.format("method is not allowed: %s", method))
	end

	if payload_encoding ~= "json" and payload_encoding ~= nil then
		error(string.format("payload_encoding is not allowed: %s", payload_encoding))
	end

	local payload = nil

	if payload_script then
		payload = utils.evaluate(payload_script, { options = options, data = data, env = env, global = _G })
	end

	if payload_encoding == "json" then
		payload = dkjson.encode(payload)
	end

	local response = requests[method](options.url, {
		headers = headers,
		data = payload,
	})

	return data
end

return webhook
