--[[
模块: 本地存储
路径: lib.store
功能: data/store.json 键值读写（任务计数、用户配置等）
依赖: lib.paths
--]]

local Paths = require("lib.paths")

local Store = {}

local cache = nil

local function storePath()
	return Paths.getDataDir() .. "/store.json"
end

local function loadAll()
	if cache then
		return cache
	end
	Paths.ensureDataDir()
	local raw = readFile(storePath())
	if raw and raw ~= "" then
		local ok, data = pcall(jsonLib.decode, raw)
		if ok and type(data) == "table" then
			cache = data
			return cache
		end
	end
	cache = {}
	return cache
end

local function saveAll()
	Paths.ensureDataDir()
	return writeFile(storePath(), jsonLib.encode(cache)) == true
end

--- 读取键值
--- @param key string
--- @param default any 键不存在时的默认值
--- @return any
function Store.get(key, default)
	local val = loadAll()[key]
	if val == nil then
		return default
	end
	return val
end

--- 写入键值
--- @param key string
--- @param value any
--- @return boolean ok
function Store.set(key, value)
	loadAll()[key] = value
	return saveAll()
end

--- 删除键
--- @param key string
--- @return boolean ok
function Store.del(key)
	loadAll()[key] = nil
	return saveAll()
end

--- 键是否存在（值为 nil 视为不存在）
--- @param key string
--- @return boolean
function Store.has(key)
	return loadAll()[key] ~= nil
end

--- 数值自增/自减
--- @param key string
--- @param delta number|nil 默认 1
--- @param default number|nil 键不存在时的初始值，默认 0
--- @return number newValue
function Store.incr(key, delta, default)
	delta = delta or 1
	default = default or 0
	local data = loadAll()
	local val = data[key]
	if val == nil then
		val = default
	end
	val = val + delta
	data[key] = val
	saveAll()
	return val
end

--- 读取全部键值（副本）
--- @return table
function Store.getAll()
	local data = loadAll()
	local copy = {}
	for k, v in pairs(data) do
		copy[k] = v
	end
	return copy
end

--- 清空存储
--- @return boolean ok
function Store.clear()
	cache = {}
	return saveAll()
end

return Store
