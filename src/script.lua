htmlparser_looplimit = 8000

local luastash = require("luastash")
local require_modules_in_directory = require("lib.utils").require_modules_in_directory
local Cache = require("lib.cache")
local default_pipeline_config_file = "/watchtower-monitor-html.json"
local default_logger_level = "info"
local default_logger_name = "watchtower-monitor-html-static-lua"

local pipeline_config_file = arg[1]
	or os.getenv("WATCHTOWER_MONITOR_HTML_STATIC_PIPELINE_CONFIG_FILE")
	or default_pipeline_config_file
local logger_level = os.getenv("WATCHTOWER_MONITOR_HTML_STATIC_LOGGER_LEVEL") or default_logger_level
local logger_name = os.getenv("WATCHTOWER_MONITOR_HTML_STATIC_LOGGER_NAME") or default_logger_name

local function main(file, options)
	local logger_level = options and options.logger_level or "info"
	local logger_name = options and options.logger_name or "watchtower-monitor-html-static-lua"

	local proccesors = {
		inputs = require_modules_in_directory("inputs"),
		filters = require_modules_in_directory("filters"),
		outputs = require_modules_in_directory("outputs"),
	}

	luastash(file, proccesors, { cache = Cache:new() }, {
		logger = luastash.Logger:new({ level = logger_level, name = logger_name }),
	})
end

if not pipeline_config_file then
	error("No pipeline config provided")
end

main(pipeline_config_file, { logger_level = logger_level, logger_name = logger_name })
