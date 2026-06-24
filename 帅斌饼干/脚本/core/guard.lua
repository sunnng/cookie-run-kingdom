--[[
模块: 弹窗守卫
路径: core.guard
功能: 比色拦截弹窗并自动处理（仅主线程调用，避免与业务并发 tap）
依赖: lib.color, lib.logger
--]]

local Color = require("lib.color")
local Logger = require("lib.logger")

local Guard = {}
local traps = {}
local sortedCache = nil

local TAG = "[Guard]"

local function invalidateSortedCache()
	sortedCache = nil
end

function Guard.register(name, feature, handler, priority)
	traps[name] = { f = feature, h = handler, p = priority or 0 }
	invalidateSortedCache()
	Logger.info(string.format(TAG .. " 注册 %s priority=%d" , name , priority or 0))
end

function Guard.clear()
	local n = 0
	for _ in pairs(traps) do
		n = n + 1
	end
	if n > 0 then
		Logger.debug(TAG .. " 清空 " .. n .. " 个 trap")
	end
	traps = {}
	invalidateSortedCache()
end

--- @return number
function Guard.trapCount()
	local n = 0
	for _ in pairs(traps) do
		n = n + 1
	end
	return n
end

local function sortedTraps()
	if sortedCache then
		return sortedCache
	end
	local list = {}
	for name, trap in pairs(traps) do
		list[#list + 1] = { name = name, trap = trap }
	end
	table.sort(list, function(a, b)
		if a.trap.p == b.trap.p then
			return a.name < b.name
		end
		return a.trap.p > b.trap.p
	end)
	sortedCache = list
	return list
end

--- 扫描并处理首个命中的守卫（按 priority 降序）
--- @return boolean handled 是否命中并已尝试处理
function Guard.check()
	for _, item in ipairs(sortedTraps()) do
		local trap = item.trap
		if Color.any(trap.f) then
			Logger.info(TAG .. " [命中] " .. item.name)
			local ok, err = pcall(trap.h)
			if not ok then
				Logger.error(TAG .. " [处理] " .. item.name .. " 失败 | " .. tostring(err))
				return false
			end
			Logger.info(TAG .. " [处理] " .. item.name .. " 完成")
			return true
		end
	end
	return false
end

--- 分片 sleep：每片 sleep 前调用 Guard.check（长等待期间清弹窗）
--- @param ms number
--- @param stepMs number|nil 默认 500
function Guard.sleep(ms, stepMs)
	stepMs = stepMs or 500
	local left = math.max(0, math.floor(ms))
	if left >= 5000 then
		Logger.debug(string.format(TAG .. " [sleep] %dms 分片 %dms" , left , stepMs))
	end
	while left > 0 do
		Guard.check()
		local chunk = math.min(left, stepMs)
		sleep(chunk)
		left = left - chunk
	end
end

return Guard
