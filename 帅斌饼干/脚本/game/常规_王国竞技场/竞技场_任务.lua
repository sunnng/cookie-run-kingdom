--[[
模块: 王国竞技场任务（过程式循环版）
路径: game.常规_王国竞技场.竞技场_任务
功能: 按流程图实现竞技场扫荡流程
--]]

local StatusHud = require("lib.status-hud")
local UserConfig = require("lib.user-config")
local Logger = require("lib.logger")
local Guard = require("core.guard")
local Touch = require("lib.touch")

local ArenaPage = require("game.常规_王国竞技场.竞技场_页面")
local ArenaRoute = require("game.常规_王国竞技场.竞技场_路由")
local ArenaSession = require("game.常规_王国竞技场.竞技场_会话")

local Task = {}
local TAG = "[王国竞技场.任务]"

local function syncSession()
	local medal , ticket = ArenaPage.readMedalAndTicket()
	local trophies = ArenaPage.readTrophyCount()
	ArenaSession.update({
		medals = medal ,
		tickets = ticket ,
		trophies = trophies ,
	})
end

local function syncStatus(cfg)
	syncSession()
	StatusHud.setTask("王国竞技场" , ArenaSession.hudText(cfg))
end

local function isReachMaxBattles(cfg)
	return ArenaSession.isReachMaxBattles(cfg)
end

local function tryAutoBuy(cfg)
	local limit = cfg.autoBuyCount or 0
	local bought = ArenaSession.get().buyCount or 0
	
	if limit <= 0 then
		Logger.info(TAG .. " 自动买票未启用，离开竞技场")
		return false
	end
	if bought >= limit then
		Logger.info(TAG .. " 已达买票上限")
		return false
	end
	
	Logger.info(TAG .. string.format(" 自动买票 第%d/%d次" , bought + 1 , limit))
	ArenaPage.buyTicket()
	ArenaSession.update({ buyCount = bought + 1 })
	Guard.sleep(1500 , 500)
	syncStatus(cfg)
	
	if (ArenaSession.get().tickets or 0) > 0 then
		return true
	end
	
	Logger.warn(TAG .. " 买票后门票仍为0，离开竞技场")
	return false
end

local function doBattle(info , cfg)
	Logger.info(string.format(
	TAG .. " 开战 奖杯=%d" ,
	info.trophies
	))
	Touch.tapR(info.site[1] , info.site[2] , 500)
	
	local result = ArenaPage.runBattle()
	if not result then
		Logger.warn(TAG .. " 战斗失败")
		return false , "战斗失败"
	end
	
	local d = ArenaSession.get()
	if result == "胜利" then
		d.wins = (d.wins or 0) + 1
	elseif result == "平局" then
		d.draws = (d.draws or 0) + 1
	elseif result == "失败" then
		d.losses = (d.losses or 0) + 1
	end
	if (d.tickets or 0) > 0 then
		d.tickets = d.tickets - 1
	end
	ArenaSession.set(d)
	syncStatus(cfg)
	
	Logger.info(string.format(
	TAG .. " 战斗完成 result=%s %s" ,
	tostring(result) , ArenaSession.describe()
	))
	return true
end

--- 扫描当前页 → 翻页扫描 → 刷新/退出
--- @return string "fought" | "refreshed" | "exit"
local function selectAndFight(cfg)
	local myTrophy = ArenaSession.get().trophies or 0
	
	-- 第 1 次扫描：当前页
	local info = ArenaPage.findFirstValidOpponent(cfg , myTrophy)
	if info then
		local ok , err = doBattle(info , cfg)
		if not ok then
			return false , err
		end
		return "fought"
	end
	
	Logger.info(TAG .. " 当前页无合适敌人，翻页扫描")
	ArenaPage.swipePageLeft()
	
	-- 第 2 次扫描：翻页后
	info = ArenaPage.findFirstValidOpponent(cfg , myTrophy)
	if info then
		local ok , err = doBattle(info , cfg)
		if not ok then
			return false , err
		end
		return "fought"
	end
	
	Logger.info(TAG .. " 翻页后仍无合适敌人")
	
	-- 尝试免费刷新
	if ArenaPage.isFreeRefresh() then
		Logger.info(TAG .. " 点击免费刷新")
		ArenaPage.tapFreeRefresh()
		ArenaSession.clearNextFreeRefresh()
		return "refreshed"
	end
	
	-- 不可刷新：解析倒计时并退出
	local seconds = ArenaPage.readRefreshCountdown()
	if seconds and seconds > 0 then
		local nextAt = os.time() + seconds
		ArenaSession.setNextFreeRefreshAt(nextAt)
		Logger.info(string.format(
		TAG .. " 免费刷新倒计时 %d秒，下次进入时间 %s" ,
		seconds , os.date("%H:%M:%S" , nextAt)
		))
	else
		Logger.warn(TAG .. " 未识别免费刷新且倒计时解析失败，默认 30 分钟后重试")
		ArenaSession.setNextFreeRefreshAt(os.time() + 30 * 60)
	end
	
	return "exit"
end

function Task.run()
	local cfg = UserConfig.get("arena")
	if cfg.enabled ~= true then
		Logger.info(TAG .. " 任务未启用，跳过")
		return false
	end
	
	if isReachMaxBattles(cfg) then
		Logger.info(TAG .. " 已达战斗上限")
		return false
	end
	
	Logger.info(string.format(
	TAG .. " 启动 上限=%s 奖杯差阈=%d 自动买票=%d" ,
	cfg.maxBattles and tostring(cfg.maxBattles) or "∞" ,
	cfg.trophyDiff or 0 ,
	cfg.autoBuyCount or 0
	))
	
	StatusHud.setTask("王国竞技场" , "进入中…")
	if not ArenaRoute.enter() then
		Logger.warn(TAG .. " 进入竞技场失败")
		StatusHud.setTask("王国竞技场" , "进入失败")
		return false
	end
	
	local running = true
	while running do
		syncStatus(cfg)
		
		if isReachMaxBattles(cfg) then
			Logger.info(TAG .. " 达到战斗上限，退出")
			break
		end
		
		if (ArenaSession.get().tickets or 0) <= 0 then
			if not tryAutoBuy(cfg) then
				break
			end
			syncStatus(cfg)
		end
		
		local result , err = selectAndFight(cfg)
		if result == false then
			Logger.warn(TAG .. " 任务结束：" .. tostring(err))
			StatusHud.setTask("王国竞技场" , "失败: " .. tostring(err))
			running = false
		elseif result == "exit" then
			running = false
		elseif result == "refreshed" then
			-- 继续循环，从第 1 页重新扫描
		end
		-- "fought" 也继续循环
	end
	
	syncSession()
	Logger.info(TAG .. " 任务结束 " .. ArenaSession.describe())
	ArenaRoute.leave()
	return true
end

return Task
