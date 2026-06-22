--[[
模块: 王国竞技场任务（状态机版）
路径: game.常规_王国竞技场.竞技场_任务
功能: 使用 core.state-machine 重构竞技场流程，便于调试、扩展与维护
--]]

local StateMachine = require("core.state-machine")
local StatusHud = require("lib.status-hud")
local UserConfig = require("lib.user-config")
local Logger = require("lib.logger")
local Guard = require("core.guard")

local ArenaPage = require("game.常规_王国竞技场.竞技场_页面")
local ArenaRoute = require("game.常规_王国竞技场.竞技场_路由")
local ArenaSession = require("game.常规_王国竞技场.竞技场_会话")

local Task = {}
local TAG = "[王国竞技场.任务]"

local PAGE_PLAN = { {1 , 2 , 3} , {2 , 3} }

local function isClose(a , b , threshold)
	if a == nil or b == nil or threshold == nil then
		return false
	end
	return math.abs(a - b) < threshold
end

local function hudText(sm)
	local c = sm.ctx.cfg
	local d = ArenaSession.get()
	local total = ArenaSession.totalBattles()
	local cap = c.maxBattles and tostring(c.maxBattles) or "∞"
	local rate = total > 0 and (d.wins or 0) / total * 100 or 0
	return string.format(
		"[%s] 战斗%d/%s 胜%d 负%d 平%d 胜率%.1f%% 门票%d 买票%d 奖杯%d" ,
		sm:getState() ,
		total , cap , d.wins or 0 , d.losses or 0 , d.draws or 0 , rate ,
		d.tickets or 0 , d.buyCount or 0 , d.trophies or 0
	)
end

local function syncStatus(sm)
	local medal , ticket = ArenaPage.readMedalAndTicket()
	local trophies = ArenaPage.readTrophyCount()
	ArenaSession.update({
		medals = medal ,
		tickets = ticket ,
		trophies = trophies ,
	})
	Logger.debug(string.format(
		TAG .. " 同步状态 奖牌=%s 门票=%s 奖杯=%s" ,
		tostring(medal) , tostring(ticket) , tostring(trophies)
	))
	StatusHud.setTask("王国竞技场" , hudText(sm))
end

local function resetSweep(sm , incrementRound)
	local ctx = sm.ctx
	ctx.pageIdx = 1
	ctx.locIdx = 1
	ctx.opponent = nil
	ctx.opponentLoc = nil
	ctx.opponentPage = nil
	ctx.promotionFlag = false
	ctx.promotionRetryCount = 0
	ctx.sweepFinished = false
	if incrementRound then
		ctx.round = ctx.round + 1
		Logger.info(TAG .. string.format(" --- 第%d轮扫荡 ---" , ctx.round))
	end
end

local function advanceSweep(sm)
	local ctx = sm.ctx
	ctx.locIdx = ctx.locIdx + 1
	local locs = PAGE_PLAN[ctx.pageIdx]
	if ctx.locIdx > #locs then
		if ctx.pageIdx < #PAGE_PLAN then
			ctx.pageIdx = ctx.pageIdx + 1
			ctx.locIdx = 1
			Logger.info(TAG .. " 第" .. (ctx.pageIdx - 1) .. "页扫完，左滑到下一页")
			ArenaPage.swipePageLeft()
			return true
		else
			return false
		end
	end
	return true
end

-- ========== 状态处理函数 ==========

local function checkEnable(sm)
	local cfg = UserConfig.get("arena")
	sm.ctx.cfg = cfg

	if cfg.enabled ~= true then
		Logger.info(TAG .. " 任务未启用，跳过")
		return StateMachine.DONE
	end

	local maxBattles = cfg.maxBattles
	if maxBattles and maxBattles > 0 and ArenaSession.totalBattles() >= maxBattles then
		Logger.info(string.format(TAG .. " 已达战斗上限 %d/%d" , ArenaSession.totalBattles() , maxBattles))
		StatusHud.setTask("王国竞技场" , "已达战斗上限")
		return StateMachine.DONE
	end

	Logger.info(string.format(
		TAG .. " 启动 上限=%s 奖杯差阈=%d 自动买票=%d %s" ,
		maxBattles and tostring(maxBattles) or "∞" ,
		cfg.trophyDiff or 0 ,
		cfg.autoBuyCount or 0 ,
		ArenaSession.describe()
	))
	return "enter"
end

local function enter(sm)
	StatusHud.setTask("王国竞技场" , "进入中…")
	if not ArenaRoute.enter() then
		Logger.warn(TAG .. " 进入竞技场失败")
		return false , "进入竞技场失败"
	end
	return "syncStatus"
end

local function syncStatusState(sm)
	syncStatus(sm)
	return "decideAction"
end

local function decideAction(sm)
	local ctx = sm.ctx
	local session = ArenaSession.get()

	-- 升段后需要重置对手列表
	if ctx.promotionFlag then
		ctx.promotionFlag = false
		Logger.info(TAG .. " 检测到升段，右滑重置对手列表")
		ArenaPage.swipePageRight()
		resetSweep(sm , false)
		return "sweep"
	end

	-- 本轮扫荡完成：进入 freeRefresh 状态处理刷新（含倒计时解析）
	if ctx.sweepFinished then
		ctx.sweepFinished = false
		return "freeRefresh"
	end

	-- 门票不足时尝试买票
	if (session.tickets or 0) <= 0 then
		return "autoBuy"
	end

	-- 继续扫荡
	return "sweep"
end

local function autoBuy(sm)
	local ctx = sm.ctx
	local limit = ctx.cfg.autoBuyCount or 0
	local bought = ArenaSession.get().buyCount or 0

	if limit <= 0 then
		Logger.info(TAG .. " 自动买票未启用，离开竞技场")
		return "leave"
	end
	if bought >= limit then
		Logger.info(string.format(TAG .. " 已达买票上限 %d/%d" , bought , limit))
		return "leave"
	end

	Logger.info(string.format(TAG .. " 自动买票 第%d/%d次" , bought + 1 , limit))
	ArenaPage.buyTicket()
	ArenaSession.update({ buyCount = bought + 1 })
	sleep(1500)
	syncStatus(sm)

	local tickets = ArenaSession.get().tickets or 0
	if tickets > 0 then
		Logger.info(TAG .. " 买票成功 当前门票=" .. tickets)
		resetSweep(sm , false)
		return "sweep"
	end

	Logger.warn(TAG .. " 买票后门票仍为0，离开竞技场")
	return "leave"
end

local function sweep(sm)
	local ctx = sm.ctx
	local session = ArenaSession.get()
	local cfg = ctx.cfg

	-- 上限保护
	local maxBattles = cfg.maxBattles
	if maxBattles and maxBattles > 0 and ArenaSession.totalBattles() >= maxBattles then
		Logger.info(string.format(TAG .. " sweep 达到战斗上限 %d" , maxBattles))
		ctx.sweepFinished = true
		return "decideAction"
	end

	-- 门票检查
	if (session.tickets or 0) <= 0 then
		Logger.info(TAG .. " sweep 门票不足")
		return "autoBuy"
	end

	local pageNum = ctx.pageIdx
	local loc = PAGE_PLAN[pageNum][ctx.locIdx]
	Logger.info(TAG .. string.format(" === 第%d页 位%d ===" , pageNum , loc))

	syncStatus(sm)
	local info = ArenaPage.readOpponentInfo(loc)
	local myTrophy = ArenaSession.get().trophies or 0

	-- 跳过已战斗
	if info.isBattled then
		Logger.info(string.format(
			TAG .. " 第%d页 位%d 已战斗(%s) 跳过" ,
			pageNum , loc , info.battleResult
		))
		if advanceSweep(sm) then
			return StateMachine.KEEP
		end
		ctx.sweepFinished = true
		return "decideAction"
	end

	-- 奖杯差过滤
	if myTrophy > info.trophies and not isClose(myTrophy , info.trophies , cfg.trophyDiff or 0) then
		Logger.info(string.format(
			TAG .. " 第%d页 位%d 奖杯过滤 我方=%d 对手=%d 差阈=%d" ,
			pageNum , loc , myTrophy , info.trophies , cfg.trophyDiff or 0
		))
		if advanceSweep(sm) then
			return StateMachine.KEEP
		end
		ctx.sweepFinished = true
		return "decideAction"
	end

	-- 找到合适对手，进入战斗
	Logger.info(string.format(
		TAG .. " 第%d页 位%d 开战 战力=%d 奖杯=%d 坐标=(%d,%d)" ,
		pageNum , loc , info.power , info.trophies , info.site[1] , info.site[2]
	))
	ctx.opponent = info
	ctx.opponentLoc = loc
	ctx.opponentPage = pageNum
	ctx.preBattleTrophies = ArenaSession.get().trophies
	ctx.promotionRetryCount = 0
	tap(info.site[1] , info.site[2])
	sleep(500)
	return "battle"
end

local function battle(sm)
	local ctx = sm.ctx
	local result = ArenaPage.runBattle()
	ctx.battleResult = result

	if not result then
		Logger.warn(TAG .. " 战斗流程异常")
		return false , "战斗流程异常"
	end

	Logger.info(string.format(TAG .. " 战斗完成 result=%s" , tostring(result)))
	return "postBattle"
end

local function postBattle(sm)
	local ctx = sm.ctx
	local result = ctx.battleResult

	-- 统计结果
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
	syncStatus(sm)
 
	-- 确保回到大厅
	if not ArenaPage.isLobby() and not ArenaPage.ensureLobby() then
		Logger.warn(TAG .. string.format(" 战斗后未能回大厅 result=%s" , tostring(result)))
		return false , "战斗后未能回大厅"
	end

	Logger.info(string.format(
		TAG .. " 战斗完成 result=%s %s" ,
		tostring(result) , ArenaSession.describe()
	))

	-- 升段判定（必须在第2页左滑复位前进行，否则可能误判）
	local freshInfo = ArenaPage.readOpponentInfo(ctx.opponentLoc)

	-- 记录奖杯变化，用于升段辅助判断
	local postTrophies = ArenaSession.get().trophies
	local trophyDelta = nil
	if ctx.preBattleTrophies and postTrophies then
		trophyDelta = postTrophies - ctx.preBattleTrophies
	end
	Logger.debug(string.format(
		TAG .. " 升段判定 对手位%d 已战=%s 战前奖杯=%s 战后奖杯=%s 变化=%s" ,
		ctx.opponentLoc , tostring(freshInfo.isBattled) ,
		tostring(ctx.preBattleTrophies) , tostring(postTrophies) , tostring(trophyDelta)
	))

	-- 对手位未识别：可能是列表刷新中或识别失败，先重试
	if freshInfo.site[1] == 0 and freshInfo.site[2] == 0 then
		ctx.promotionRetryCount = ctx.promotionRetryCount + 1
		if ctx.promotionRetryCount > 3 then
			Logger.warn(TAG .. string.format(
				" 第%d页 位%d 升段判定重试超限，按升段处理" ,
				ctx.opponentPage , ctx.opponentLoc
			))
			ctx.promotionFlag = true
			ctx.promotionRetryCount = 0
			return "decideAction"
		end
		Logger.debug(TAG .. string.format(
			" 第%d页 位%d 对手位未识别，等待刷新 retry=%d" ,
			ctx.opponentPage , ctx.opponentLoc , ctx.promotionRetryCount
		))
		sleep(1000)
		return StateMachine.KEEP
	end

	-- 对手位存在但未标记已战：可能是升段，也可能是颜色识别失败/列表自然刷新
	if not freshInfo.isBattled then
		ctx.promotionRetryCount = ctx.promotionRetryCount + 1
		if ctx.promotionRetryCount > 3 then
			-- 多次重试仍显示未战，判定升段
			Logger.info(string.format(
				TAG .. " 第%d页 位%d 对手信息未刷新，判定升段" ,
				ctx.opponentPage , ctx.opponentLoc
			))
			ctx.promotionFlag = true
			ctx.promotionRetryCount = 0
			return "decideAction"
		end
		Logger.debug(TAG .. string.format(
			" 第%d页 位%d 未标记已战，等待重试 retry=%d" ,
			ctx.opponentPage , ctx.opponentLoc , ctx.promotionRetryCount
		))
		sleep(1000)
		return StateMachine.KEEP
	end

	ctx.promotionRetryCount = 0

	-- 确认未升段后，第2页战斗后左滑复位
	if ctx.opponentPage == 2 then
		Logger.debug(TAG .. " 第2页战斗后左滑复位")
		ArenaPage.swipePageLeft()
	end

	-- 继续下一个位置
	if advanceSweep(sm) then
		return StateMachine.KEEP
	end
	ctx.sweepFinished = true
	return "decideAction"
end

local function freeRefresh(sm)
	if ArenaPage.isFreeRefresh() then
		Logger.info(TAG .. " 点击免费刷新")
		ArenaPage.tapFreeRefresh()
		sleep(1000)
		ArenaSession.clearNextFreeRefresh()
		Logger.info(TAG .. " 免费刷新完成")
		resetSweep(sm , true)
		return "syncStatus"
	end

	-- 未识别免费刷新，读取倒计时并安排下次进入时间
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

	return "leave"
end

local function leave(sm)
	syncStatus(sm)
	Logger.info(TAG .. " 任务结束 " .. ArenaSession.describe())
	ArenaRoute.leave()
	return StateMachine.DONE
end

local handlers = {
	checkEnable = checkEnable ,
	enter = enter ,
	syncStatus = syncStatusState ,
	decideAction = decideAction ,
	autoBuy = autoBuy ,
	sweep = sweep ,
	battle = battle ,
	postBattle = postBattle ,
	freeRefresh = freeRefresh ,
	leave = leave ,
}

function Task.run()
	local cfg = UserConfig.get("arena")
	if cfg.enabled ~= true then
		Logger.info(TAG .. " 任务未启用，跳过")
		return false
	end

	local ctx = {
		cfg = cfg ,
		round = 0 ,
		pageIdx = 1 ,
		locIdx = 1 ,
		opponent = nil ,
		opponentLoc = nil ,
		opponentPage = nil ,
		battleResult = nil ,
		promotionFlag = false ,
		promotionRetryCount = 0 ,
		preBattleTrophies = nil ,
		sweepFinished = false ,
	}

	local sm = StateMachine.new()
	sm:init("checkEnable" , {
		maxRetry = 3 ,
		maxError = 3 ,
		timeout = 3600 , -- 竞技场任务整体超时 1 小时
		retryIntervalMs = 1000 ,
	})
	sm.ctx = ctx
	resetSweep(sm , true) -- 初始化第 1 轮

	local ok , err = sm:run(handlers , {
		interval = 500 ,
		guard = Guard.check ,
		label = "王国竞技场" ,
	})

	if ok then
		Logger.info(TAG .. " 任务正常结束")
	else
		Logger.warn(TAG .. " 任务结束：" .. tostring(err))
		StatusHud.setTask("王国竞技场" , "失败: " .. tostring(err))
	end

	return ok
end

return Task
