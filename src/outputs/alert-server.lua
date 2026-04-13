local requests = require("requests")
local dkjson = require("dkjson")

-- Define the interpolation function
local function interpolate(template, env)
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

local destinations = {
	discord = function(options, ctx)
		if not options.message then
			error("Template message was not defined.")
		end

		if not options.url then
			error("webhook_url is not defined")
		end

		local content = interpolate(options.message, ctx)
		local response = requests.post(options.url, {
			headers = { ["Content-Type"] = "application/json" },
			data = {
				content = content,
			},
		})
		return response.status_code >= 200 and response.status_code <= 299, response.text
	end,
}

local function fetch_alerts_config(url, method)
	local response = requests[method or "get"](url, {
		headers = { ["Content-Type"] = "application/json" },
	})

	return dkjson.decode(response.text)
end

local function alert_server(options, ctx, env, utils)
	local logger = utils.logger:get_logger({ name = "alert-server-connector:" .. ctx.id, level = "debug" })

	local method = options and options.method or "post"
	local alerts_url = options and options.alerts_url
	local payload_script = options and options.payload_script

	if not alerts_url then
		local err = "url is not defined"
		logger.error(err)
		error(err)
	end

	local url_resolved = interpolate(alerts_url, { ctx = ctx })

	logger.debug("Resolved URL: %s", url_resolved)

	logger.debug("Fetching alerts from %s", url_resolved)
	local alerts = fetch_alerts_config(url_resolved)
	logger.debug("Alerts fetched from %s; %s", url_resolved, dkjson.encode(alerts))

	if alerts ~= nil and alerts.items ~= nil then
		for i, alert in ipairs(alerts.items) do
			local logger_alert = logger:get_logger({ name = alert.name })
			logger_alert.debug("Alert: %s", dkjson.encode(alert))

			if alert.enabled then
				logger_alert.debug("Alert is enabled")
				logger_alert.debug("Checking triggers")

				local should_generate_alert = false

				if alert.trigger_on_discount and ctx.discount then
					logger_alert.debug("Trigger alert by discount")
					should_generate_alert = true
				end

				if alert.trigger_on_available and ctx.available then
					logger_alert.debug("Trigger alert by available")
					should_generate_alert = true
				end

				if
					alert.trigger_on_price and utils.evaluate(string.format("return %s", alert.trigger_on_price), ctx)
				then
					logger_alert.debug("Trigger alert by condition")
					should_generate_alert = true
				end

				if should_generate_alert then
					logger_alert.debug("Generating alert")

					if alert.channels ~= nil then
						logger_alert.debug("Channel availables in alert: %s", dkjson.encode(alert.channels))
						for _, channel in ipairs(alert.channels) do
							local logger_channel = logger_alert:get_logger({
								name = string.format("%s[type=%s]", channel.name, channel.type),
							})

							logger_channel.debug("Channel available in alert: %s", dkjson.encode(channel))
							if destinations[channel.type] ~= nil then
								logger_channel.debug("Running destination")
								local ok, err = destinations[channel.type](
									channel.options,
									{ ctx = ctx, alert = alert, channel = channel }
								)

								if ok then
									logger_channel.info("Destination acknowledged", err)
								else
									logger_channel.error("Destination had a problem", err)
								end
							else
								logger_alert.warn("Destination not supported")
							end
						end
					else
						logger_alert.warn("No channels for found")
					end
				else
					logger_alert.warn("Triggers were not fulfilled")
				end
			else
				logger_alert.warn("Alert is disabled")
			end
		end
	else
		logger.warn("No alerts found")
	end

	return ctx
end

return alert_server
