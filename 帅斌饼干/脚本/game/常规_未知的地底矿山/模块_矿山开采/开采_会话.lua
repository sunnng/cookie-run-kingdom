--[[
模块: 矿山开采会话
路径: game.常规_未知的地底矿山.模块_矿山开采.开采_会话
功能: 开采完成后 busy 等待截止时间持久化（跨轮次由 register condition 检查）
依赖: lib.store, lib.user-config
--]]

local Store = require("lib.store")
local Logger = require("lib.logger")
local UserConfig = require("lib.user-config")

local Session = {}
local KEY = "mine_mining_session"
local TAG = "[矿山开采.会话]"
local DEFAULT_BUSY_SEC = 6 * 3600

--- @return number
local function resolveBusySec()
	local cfg = UserConfig.get("mine")
	local sec = cfg and cfg.miningIntervalSec
	if type(sec) == "number" and sec > 0 then
		return math.floor(sec)
	end
	return DEFAULT_BUSY_SEC
end

--- @return table|nil
local function loadRaw()
	local raw = Store.get(KEY)
	if type(raw) ~= "table" then
		return nil
	end
	return raw
end

--- 所有栏位 busy 剩余秒数（0 表示无等待或已到期）
--- @return number remainSec
function Session.restoreProgress()
	local raw = loadRaw()
	if not raw or not raw.allBusyUntil then
		Logger.debug(TAG .. " restoreProgress: 无 busy 记录")
		return 0
	end
	local remain = raw.allBusyUntil - os.time()
	if remain > 0 then
		Logger.debug(string.format(TAG .. " restoreProgress: busy 剩余 %ds" , remain))
		return remain
	end
	Logger.debug(TAG .. " restoreProgress: busy 已到期")
	return 0
end

--- 进入 busy 等待（开采页确认没有已完成/空闲/可启动栏位时调用）
--- @param waitSec number|nil  默认读 UserConfig.mine.miningIntervalSec（6 小时）
function Session.enterBusyWait(waitSec)
	waitSec = waitSec or resolveBusySec()
	local until_ = os.time() + waitSec
	Store.set(KEY , {
		allBusyUntil = until_ ,
		recordedAt = os.time() ,
	})
	Logger.info(string.format(TAG .. " enterBusyWait: busy %ds（到期戳 %d）" , waitSec , until_))
end

--- 检查是否可运行（busy 等待是否已到期）
--- @return boolean ok
--- @return number remainSec
function Session.checkReady()
	local raw = loadRaw()
	if not raw or not raw.allBusyUntil then
		return true , 0
	end
	local remain = raw.allBusyUntil - os.time()
	if remain <= 0 then
		Logger.debug(TAG .. " checkReady: busy 已到期，可运行")
		return true , 0
	end
	Logger.debug(string.format(TAG .. " checkReady: busy 中，剩余 %ds，本轮跳过" , remain))
	return false , remain
end

--- 清理会话
function Session.clear()
	Store.set(KEY , {})
	Logger.info(TAG .. " clear: 会话已清理")
end

--- 会话状态摘要（供 UI / HUD 调试展示）
--- @return string
function Session.describe()
	local raw = loadRaw()
	if not raw or not raw.allBusyUntil then
		return "无 busy 记录"
	end
	local remain = raw.allBusyUntil - os.time()
	if remain > 0 then
		return string.format("矿卡开采中，剩余 %ds" , remain)
	end
	return "busy 已到期（记录仍在，可清除）"
end

return Session
