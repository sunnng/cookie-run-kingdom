--[[
模块: 梦幻繁星岛会话
路径: game.常规_梦幻繁星岛.繁星岛_会话
功能: 今日完成标记持久化
依赖: lib.store
--]]

local Store = require("lib.store")

local Session = {}

local KEY_DONE = "starlight_done_date"

local function today()
	return os.date("%Y-%m-%d")
end

--- @return boolean
function Session.isDoneToday()
	return Store.get(KEY_DONE) == today()
end

function Session.markDoneToday()
	Store.set(KEY_DONE , today())
end

function Session.clear()
	Store.del(KEY_DONE)
end

--- @return string
function Session.describe()
	if Session.isDoneToday() then
		return "今日已完成"
	end
	return "今日未完成"
end

return Session
