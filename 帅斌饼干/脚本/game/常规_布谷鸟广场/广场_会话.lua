--[[
模块: 布谷鸟广场会话
路径: game.常规_布谷鸟广场.广场_会话
功能: 今日完成标记、广场/离开弹窗内有效停留累计
依赖: lib.store
--]]

local Store = require("lib.store")

local Session = {}

local KEY_DONE = "cuckoo_square_done_date"
local KEY_ACTIVE = "cuckoo_square_active"

local function today()
	return os.date("%Y-%m-%d")
end

local function now()
	return os.time()
end

--- @return boolean
function Session.isDoneToday()
	return Store.get(KEY_DONE) == today()
end

function Session.markDoneToday()
	Store.set(KEY_DONE , today())
	Session.clear()
end

--- @return table|nil
function Session.getActive()
	local data = Store.get(KEY_ACTIVE)
	if type(data) ~= "table" then
		return nil
	end
	data.accumulatedSec = tonumber(data.accumulatedSec) or 0
	return data
end

--- @return boolean
function Session.isActive()
	return Session.getActive() ~= nil
end

--- @param active table
function Session.save(active)
	Store.set(KEY_ACTIVE , active)
end

function Session.clear()
	Store.del(KEY_ACTIVE)
end

function Session.clearAll()
	Store.del(KEY_DONE)
	Store.del(KEY_ACTIVE)
end

--- @return table
function Session.ensure()
	local active = Session.getActive()
	if active then
		return active
	end
	active = {
		startedAt = now() ,
		accumulatedSec = 0 ,
		lastEnterAt = nil ,
		checkedDate = nil ,
	}
	Session.save(active)
	return active
end

function Session.markCheckedToday()
	local active = Session.ensure()
	active.checkedDate = today()
	Session.save(active)
end

--- @return boolean
function Session.hasCheckedToday()
	local active = Session.getActive()
	return active ~= nil and active.checkedDate == today()
end

--- 开始/恢复广场有效停留计时
function Session.startStay()
	local active = Session.ensure()
	if not active.lastEnterAt then
		active.lastEnterAt = now()
		Session.save(active)
	end
end

--- 暂停计时，并结算当前已在广场/弹窗内停留的秒数
function Session.pauseStay()
	local active = Session.getActive()
	if not active or not active.lastEnterAt then
		return
	end
	active.accumulatedSec = (tonumber(active.accumulatedSec) or 0) + math.max(0 , now() - active.lastEnterAt)
	active.lastEnterAt = nil
	Session.save(active)
end

--- 重置一轮奖励结算所需的有效停留计时
function Session.resetStayTimer()
	local active = Session.ensure()
	active.accumulatedSec = 0
	active.lastEnterAt = now()
	Session.save(active)
end

--- @return number
function Session.stayElapsed()
	local active = Session.getActive()
	if not active then
		return 0
	end
	local elapsed = tonumber(active.accumulatedSec) or 0
	if active.lastEnterAt then
		elapsed = elapsed + math.max(0 , now() - active.lastEnterAt)
	end
	return elapsed
end

--- @param requiredSec number|nil
--- @return number
function Session.stayRemaining(requiredSec)
	requiredSec = requiredSec or 60
	return math.max(0 , requiredSec - Session.stayElapsed())
end

--- @return string
function Session.describe()
	if Session.isDoneToday() then
		return "今日已完成"
	end
	local active = Session.getActive()
	if not active then
		return "今日未完成，无挂机会话"
	end
	local checked = active.checkedDate == today() and "已初检" or "未初检"
	return string.format(
		"今日未完成，%s，有效停留 %ds" ,
		checked ,
		math.floor(Session.stayElapsed())
	)
end

return Session
