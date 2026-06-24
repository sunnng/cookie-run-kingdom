--[[
模块: 矿山战斗会话
路径: game.常规_未知的地底矿山.模块_矿山战斗.战斗_会话
功能: 记录上次战斗时间，控制战斗检测频率
依赖: lib.store
--]]

local Store = require("lib.store")
local Logger = require("lib.logger")

local Session = {}
local KEY = "mine_battle_session"
local TAG = "[矿山战斗.会话]"

--- 获取距离下次战斗还剩多少秒
--- @param intervalSec number 用户配置的间隔（秒）
--- @return number remainSec 剩余秒数，0 表示可运行
function Session.getTimeUntilNext(intervalSec)
	intervalSec = intervalSec or 21600
	local raw = Store.get(KEY)
	if type(raw) ~= "table" or not raw.lastBattleAt then
		Logger.debug(TAG .. " getTimeUntilNext: 无上次战斗记录")
		return 0
	end
	local remain = raw.lastBattleAt + intervalSec - os.time()
	if remain > 0 then
		Logger.debug(string.format(TAG .. " getTimeUntilNext: 冷却中，剩余 %ds" , remain))
		return remain
	end
	Logger.debug(TAG .. " getTimeUntilNext: 冷却已到期")
	return 0
end

--- 记录本次战斗开始时间
function Session.recordBattle()
	Store.set(KEY, { lastBattleAt = os.time() })
	Logger.info(TAG .. " recordBattle: 已记录战斗时间 " .. os.date("%H:%M:%S" , os.time()))
end

--- 清理会话
function Session.clear()
	Store.set(KEY, {})
	Logger.info(TAG .. " clear: 会话已清理")
end

--- 会话状态摘要（供 UI / HUD 调试展示）
--- @param intervalSec number
--- @return string
function Session.describe(intervalSec)
	intervalSec = intervalSec or 21600
	local raw = Store.get(KEY)
	if type(raw) ~= "table" or not raw.lastBattleAt then
		return "无战斗记录"
	end
	local remain = raw.lastBattleAt + intervalSec - os.time()
	if remain > 0 then
		return string.format("冷却中，剩余 %ds（约%.1f小时）" , remain , remain / 3600)
	end
	return "冷却已到期（记录仍在，可清除）"
end

return Session
