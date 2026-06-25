--[[
模块: 王国竞技场会话
路径: game.常规_王国竞技场.竞技场_会话
--]]

local Store = require("lib.store")

local Session = {}
local KEY = "arena_session"

function Session.get()
	return Store.get(KEY) or {}
end

function Session.set(data)
	Store.set(KEY , data)
end

function Session.update(partial)
	local data = Session.get()
	for k , v in pairs(partial) do
		data[k] = v
	end
	Session.set(data)
	return data
end

function Session.totalBattles()
	local d = Session.get()
	return (d.wins or 0) + (d.losses or 0) + (d.draws or 0)
end

--- 是否已达到用户设置的最大战斗次数
--- @param cfg table arena 配置（含 maxBattles）
--- @return boolean
function Session.isReachMaxBattles(cfg)
	local maxBattles = cfg and cfg.maxBattles
	return maxBattles and maxBattles > 0 and Session.totalBattles() >= maxBattles
end

function Session.describe()
	local d = Session.get()
	local total = Session.totalBattles()
	local rate = total > 0 and (d.wins or 0) / total * 100 or 0
	return string.format(
		"战斗%d 胜%d 负%d 平%d 胜率%.1f%% 门票%d 买票%d 奖杯%d" ,
		total , d.wins or 0 , d.losses or 0 , d.draws or 0 , rate ,
		d.tickets or 0 , d.buyCount or 0 , d.trophies or 0
	)
end

--- 生成顶部 HUD 显示的完整竞技场比赛统计
--- @param cfg table arena 配置（含 maxBattles）
--- @return string
function Session.hudText(cfg)
	local d = Session.get()
	local total = Session.totalBattles()
	local cap = cfg and cfg.maxBattles and tostring(cfg.maxBattles) or "∞"
	local rate = total > 0 and (d.wins or 0) / total * 100 or 0
	return string.format(
		"总%d/%s 胜%d 负%d 平%d 胜率%.1f%% 门票%d 买票%d 奖杯%d" ,
		total , cap , d.wins or 0 , d.losses or 0 , d.draws or 0 , rate ,
		d.tickets or 0 , d.buyCount or 0 , d.trophies or 0
	)
end

function Session.clear()
	Store.set(KEY , {})
end

--- 设置下次免费刷新时间戳（秒级）
--- @param at number os.time() 格式的时间戳
function Session.setNextFreeRefreshAt(at)
	Session.update({ nextFreeRefreshAt = at })
end

--- 获取距离下次免费刷新还剩多少秒
--- @return number 剩余秒数，0 表示已到期或未设置
function Session.getTimeUntilRefresh()
	local d = Session.get()
	local at = d.nextFreeRefreshAt
	if not at or at <= 0 then
		return 0
	end
	local remain = at - os.time()
	return remain > 0 and remain or 0
end

--- 清除免费刷新等待时间
function Session.clearNextFreeRefresh()
	Session.update({ nextFreeRefreshAt = 0 })
end

return Session
