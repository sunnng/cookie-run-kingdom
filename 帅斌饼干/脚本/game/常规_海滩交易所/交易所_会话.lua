local Store = require("lib.store")
local Logger = require("lib.logger")
local UserConfig = require("lib.user-config")

local Session = {}
local KEY = "seaside_market_session"
local TAG = "[海滩交易所.会话]"
local DEFAULT_RESTOCK_SEC = 6 * 3600
local startupBypassPending = true
local startupBypassActive = false

local function cfg()
	return UserConfig.get("seasideMarket") or {}
end

local function bufferSec()
	local sec = cfg().restockBufferSec
	if type(sec) == "number" and sec >= 0 then
		return math.floor(sec)
	end
	return 30
end

local function loadRaw()
	local raw = Store.get(KEY)
	if type(raw) ~= "table" then
		return nil
	end
	return raw
end

function Session.restoreProgress()
	local raw = loadRaw()
	if not raw or not raw.nextRunAt then
		return 0
	end
	local remain = raw.nextRunAt - os.time()
	if remain > 0 then
		return remain
	end
	return 0
end

function Session.scheduleAfterRestock(restockSec)
	if type(restockSec) ~= "number" or restockSec < 0 then
		restockSec = DEFAULT_RESTOCK_SEC
	end
	local waitSec = math.floor(restockSec) + bufferSec()
	local nextRunAt = os.time() + waitSec
	Store.set(KEY , {
		nextRunAt = nextRunAt ,
		restockSec = math.floor(restockSec) ,
		bufferSec = bufferSec() ,
		recordedAt = os.time() ,
	})
	Logger.info(string.format(TAG .. " 下次补货调度 %ds 后（到期戳 %d）" , waitSec , nextRunAt))
end

function Session.checkReady()
	if startupBypassPending then
		startupBypassPending = false
		startupBypassActive = true
		Logger.info(TAG .. " 本次脚本启动首轮强制执行，忽略补货等待")
		return true , 0
	end
	local raw = loadRaw()
	if not raw or not raw.nextRunAt then
		return true , 0
	end
	local remain = raw.nextRunAt - os.time()
	if remain <= 0 then
		return true , 0
	end
	Logger.debug(string.format(TAG .. " 补货等待中，剩余 %ds" , remain))
	return false , remain
end

function Session.consumeStartupBypass()
	if startupBypassActive then
		startupBypassActive = false
		return true
	end
	return false
end

function Session.clear()
	Store.set(KEY , {})
	Logger.info(TAG .. " 会话已清理")
end

function Session.describe()
	local raw = loadRaw()
	if not raw or not raw.nextRunAt then
		return "无补货等待"
	end
	local remain = raw.nextRunAt - os.time()
	if remain > 0 then
		return string.format("补货等待中，剩余 %ds" , remain)
	end
	return "补货已到期"
end

return Session
