--[[
模块: 用户配置
路径: lib.user-config
功能: 默认值(config.USER) + 持久化(store)，按模块名读写
依赖: config, lib.store
--]]

local Config = require("config")
local Store = require("lib.store")

local UserConfig = {}

local STORE_KEY = "user_config"
local cache = nil

local function copyTable(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = copyTable(v)
	end
	return c
end

local function mergeSection(defaults, saved)
	local out = copyTable(defaults)
	if type(saved) == "table" then
		for k, v in pairs(saved) do
			out[k] = v
		end
	end
	return out
end

--- @return table
function UserConfig.load()
	if cache then
		return cache
	end
	local saved = Store.get(STORE_KEY)
	cache = {}
	for section, defaults in pairs(Config.userDefaults()) do
		local over = type(saved) == "table" and saved[section] or nil
		cache[section] = mergeSection(defaults, over)
	end
	return cache
end

--- @param section string 如 "mine" / "biscuit"
--- @return table
function UserConfig.get(section)
	return UserConfig.load()[section]
end

--- @param section string
--- @param partial table
function UserConfig.set(section, partial)
	local cfg = UserConfig.load()
	for k, v in pairs(partial) do
		cfg[section][k] = v
	end
end

--- @return boolean
function UserConfig.save()
	return Store.set(STORE_KEY, UserConfig.load())
end

return UserConfig
