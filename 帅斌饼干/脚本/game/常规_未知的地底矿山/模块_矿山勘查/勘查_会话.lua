--[[
模块: 矿山勘查会话
路径: game.常规_未知的地底矿山.模块_矿山勘查.勘查_会话
功能: 远距等待截止时间持久化（跨轮次由 register condition 检查）
依赖: lib.store
--]]

local Store = require("lib.store")
local Logger = require("lib.logger")

local Session = {}
local KEY = "mine_venture_session"
local TAG = "[矿山勘查.会话]"

--- 远距等待剩余秒数（0 表示无等待或已到期）
--- @return number remainSec
function Session.restoreProgress()
	local raw = Store.get(KEY)
	if type(raw) ~= "table" then
		Logger.debug(TAG .. " restoreProgress: 无会话记录")
		return 0
	end
	local remain = (raw.farWaitUntil or 0) - os.time()
	if remain > 0 then
		Logger.debug(string.format(TAG .. " restoreProgress: 远距等待剩余 %ds" , remain))
		return remain
	end
	Logger.debug(TAG .. " restoreProgress: 等待已到期或无截止时间")
	return 0
end

--- 进入远距等待
--- @param waitSec number
function Session.enterFarWait(waitSec)
	local until_ = os.time() + (waitSec or 600)
	Store.set(KEY, { farWaitUntil = until_ })
	Logger.info(string.format(TAG .. " enterFarWait: 进入远距等待 %ds（到期戳 %d）" , waitSec or 600 , until_))
end

--- 检查是否可运行（远距等待是否已到期）
--- @return boolean ok
--- @return number remainSec
function Session.checkFarWait()
	local raw = Store.get(KEY)
	if type(raw) ~= "table" or not raw.farWaitUntil then
		return true, 0
	end
	local remain = raw.farWaitUntil - os.time()
	if remain <= 0 then
		Logger.debug(TAG .. " checkFarWait: 等待已到期，可运行")
		return true, 0
	end
	Logger.debug(string.format(TAG .. " checkFarWait: 等待中，剩余 %ds，本轮跳过" , remain))
	return false, remain
end

--- 清理会话
function Session.clear()
	Store.set(KEY, {})
	Logger.info(TAG .. " clear: 会话已清理")
end

--- 会话状态摘要（供 UI / HUD 调试展示）
--- @return string
function Session.describe()
	local raw = Store.get(KEY)
	if type(raw) ~= "table" or not raw.farWaitUntil then
		return "无远距等待记录"
	end
	local remain = raw.farWaitUntil - os.time()
	if remain > 0 then
		return string.format("远距等待中，剩余 %ds" , remain)
	end
	return "等待已到期（记录仍在，可清除）"
end

return Session
