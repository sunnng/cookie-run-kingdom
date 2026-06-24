--[[
模块: 业务注册
路径: game.register
功能: 将守卫陷阱、调度任务注入核心框架
依赖: core.scheduler, core.guard, lib.store, lib.logger, game.flows, game.pages
--]]

local Scheduler = require("core.scheduler")
local Guard = require("core.guard")
local Logger = require("lib.logger")
local UserConfig = require("lib.user-config")
local StatusHud = require("lib.status-hud")
local Dialog = require("lib.dialog")

local MineTask = require("game.常规_未知的地底矿山.模块_矿山勘查.勘查_任务")
local MiningTask = require("game.常规_未知的地底矿山.模块_矿山开采.开采_任务")
local BattleTask = require("game.常规_未知的地底矿山.模块_矿山战斗.战斗_任务")
local BattleSession = require("game.常规_未知的地底矿山.模块_矿山战斗.战斗_会话")
local MiningPage = require("game.常规_未知的地底矿山.模块_矿山开采.开采_页面")
local BiscuitTask = require("game.功能_洗脆饼.task")
local SquareTask = require("game.常规_布谷鸟广场.广场_任务")
local SquareRoute = require("game.常规_布谷鸟广场.广场_路由")
local SquareSession = require("game.常规_布谷鸟广场.广场_会话")
local SeasideMarketTask = require("game.常规_海滩交易所.交易所_任务")
local SeasideMarketSession = require("game.常规_海滩交易所.交易所_会话")
local ArenaTask = require("game.常规_王国竞技场.竞技场_任务")
local ArenaSession = require("game.常规_王国竞技场.竞技场_会话")
local Session = require("game.常规_未知的地底矿山.模块_矿山勘查.勘查_会话")
local MiningSession = require("game.常规_未知的地底矿山.模块_矿山开采.开采_会话")
local PopupPage = require("game.通用_弹窗.page")
local StarlightTask = require("game.常规_梦幻繁星岛.繁星岛_任务")
local StarlightSession = require("game.常规_梦幻繁星岛.繁星岛_会话")
local JellyTask = require("game.常规_未知的地底矿山.模块_解除洋菜冻.解除洋菜冻_任务")
local JellySession = require("game.常规_未知的地底矿山.模块_解除洋菜冻.解除洋菜冻_会话")

local Register = {}

--- 勘查远距 / 开采 busy 合并展示（任一项在等时更新 HUD）
local function updateMineWaitHud(extra)
	local mineCfg = UserConfig.get("mine")
	local surveySec = mineCfg.surveyEnabled and Session.restoreProgress() or 0
	local miningSec = mineCfg.miningEnabled and MiningSession.restoreProgress() or 0
	if surveySec > 0 or miningSec > 0 then
		StatusHud.setMineWait({
			surveySec = surveySec > 0 and surveySec or nil ,
			miningSec = miningSec > 0 and miningSec or nil ,
			extra = extra ,
		})
	end
end

--- 矿山调度侧是否没有到期任务
--- @return boolean
local function isMineSchedulerIdle()
	local mineCfg = UserConfig.get("mine")
	if mineCfg.surveyEnabled then
		local canSurvey = Session.checkFarWait()
		if canSurvey then
			return false
		end
	end
	if mineCfg.miningEnabled == true then
		local canMining = MiningSession.checkReady()
		if canMining then
			return false
		end
	end
	if mineCfg.jellyEnabled == true then
		local canJelly, _ = JellySession.checkReady()
		if canJelly then
			return false
		end
	end
	return true
end

function Register.all()
	Scheduler.clear()
	Guard.clear()

	-- ========== 守卫注册（优先级高->低）==========
	local unstableNetworkPopup = PopupPage["网络联机状态不稳定"]
	local unstableDialog = Dialog.new({
		name = "网络联机状态不稳定",
		feature = unstableNetworkPopup["特征"],
		confirmBtn = unstableNetworkPopup["按钮_确认"],
	}, { tag = "[Register]" })
	Guard.register(
		"网络联机状态不稳定",
		unstableDialog.def.feature,
		unstableDialog:toGuardHandler({ action = "confirm", waitGoneMs = 2000 }),
		10
	)


	-- ========== 调度任务注册（矿山优先，空闲时布谷鸟广场短切片）==========
	-- 矿山：状态机驱动，计数存储
	Scheduler.add("矿山勘查",
		function()
			-- 1. 用户是否开启矿山勘查功能
			if not UserConfig.get("mine").surveyEnabled then
				return false
			end

			-- 2. 远距等待是否达到目标时间
			local canRun , remain = Session.checkFarWait()
			if not canRun then
				updateMineWaitHud("调度等待")
				Logger.info("[Register] 矿山远距等待中")
				return false
			end

			return true
		end,
		function()
			if SquareRoute.isSquareContext() then
				Logger.info("[Register] 矿山前离开广场")
				if not SquareTask.leaveForOtherTask() then
					Logger.warn("[Register] 离开广场失败，跳过矿山")
					return
				end
			end
			Logger.info("[Register] 开始矿山勘查任务")
			if MineTask.run() then
				Logger.info("[Register] mine done")
			end
		end)

	-- 矿山开采：状态机驱动，busy 等待存储
	Scheduler.add("矿山开采",
		function()
			if UserConfig.get("mine").miningEnabled ~= true then
				return false
			end
			if MiningPage.isMiningPage() or MiningPage.isRewardPage() then
				Logger.info("[Register] 当前仍在矿山开采页，允许开采任务恢复")
				return true
			end
			local canRun , remain = MiningSession.checkReady()
			if not canRun then
				updateMineWaitHud("调度等待")
				Logger.info("[Register] 矿山开采 busy 等待中")
				return false
			end
			return true
		end,
		function()
			if SquareRoute.isSquareContext() then
				Logger.info("[Register] 矿山开采前离开广场")
				if not SquareTask.leaveForOtherTask() then
					Logger.warn("[Register] 离开广场失败，跳过矿山开采")
					return
				end
			end
			Logger.info("[Register] 开始矿山开采任务")
			if MiningTask.run() then
				Logger.info("[Register] 矿山开采完成")
			end
		end)

	Scheduler.add("矿山战斗",
		function()
			local mineCfg = UserConfig.get("mine")
			if mineCfg.battleEnabled ~= true then
				return false
			end
			local interval = mineCfg.battleIntervalSec or 21600
			local remain = BattleSession.getTimeUntilNext(interval)
			if remain > 0 then
				StatusHud.setTask("矿山战斗" , string.format("冷却等待 %ds" , remain))
				Logger.info("[Register] 矿山战斗冷却中 " .. remain .. "s")
				return false
			end
			return true
		end,
		function()
			if SquareRoute.isSquareContext() then
				Logger.info("[Register] 矿山战斗前离开广场")
				if not SquareTask.leaveForOtherTask() then
					Logger.warn("[Register] 离开广场失败，跳过矿山战斗")
					return
				end
			end
			Logger.info("[Register] 开始矿山战斗任务")
			if BattleTask.run() then
				Logger.info("[Register] 矿山战斗完成")
			end
		end)

	Scheduler.add("解除洋菜冻",
		function()
			local mineCfg = UserConfig.get("mine")
			if mineCfg.jellyEnabled ~= true then
				return false
			end
			local canRun , remain = JellySession.checkReady()
			if not canRun then
				StatusHud.setTask("解除洋菜冻" , string.format("冷却等待 %ds" , remain))
				Logger.info("[Register] 解除洋菜冻冷却中 " .. remain .. "s")
				return false
			end
			return true
		end,
		function()
			if SquareRoute.isSquareContext() then
				Logger.info("[Register] 解除洋菜冻前离开广场")
				if not SquareTask.leaveForOtherTask() then
					Logger.warn("[Register] 离开广场失败，跳过解除洋菜冻")
					return
				end
			end
			Logger.info("[Register] 开始解除洋菜冻任务")
			if JellyTask.run() then
				Logger.info("[Register] 解除洋菜冻完成")
			end
		end)

	Scheduler.add("海滩交易所",
		function()
			local market = UserConfig.get("seasideMarket")
			if not market or market.enabled ~= true then
				return false
			end
			if not isMineSchedulerIdle() then
				updateMineWaitHud("矿山待执行")
				Logger.info("[Register] 矿山待执行，跳过海滩交易所")
				return false
			end
			local canRun , remain = SeasideMarketSession.checkReady()
			if not canRun then
				StatusHud.setTask("海滩交易所" , string.format("补货等待 %ds" , remain))
				Logger.info("[Register] 海滩交易所补货等待中")
				return false
			end
			return true
		end,
		function()
			if SquareRoute.isSquareContext() then
				Logger.info("[Register] 海滩交易所前离开广场")
				if not SquareTask.leaveForOtherTask() then
					Logger.warn("[Register] 离开广场失败，跳过海滩交易所")
					return
				end
			end
			Logger.info("[Register] 开始海滩交易所任务")
			SeasideMarketTask.run()
		end)

	Scheduler.add("王国竞技场",
		function()
			local arena = UserConfig.get("arena")
			if not arena or arena.enabled ~= true then
				return false
			end
			if not isMineSchedulerIdle() then
				updateMineWaitHud("矿山待执行")
				Logger.info("[Register] 矿山待执行，跳过王国竞技场")
				return false
			end
			local maxBattles = arena.maxBattles
			if maxBattles and maxBattles > 0 then
				if ArenaSession.totalBattles() >= maxBattles then
					return false
				end
			end
			local refreshRemain = ArenaSession.getTimeUntilRefresh()
			if refreshRemain > 0 then
				StatusHud.setTask("王国竞技场" , string.format("刷新等待 %ds" , refreshRemain))
				Logger.info("[Register] 竞技场免费刷新等待中 " .. refreshRemain .. "s")
				return false
			end
			return true
		end,
		function()
			if SquareRoute.isSquareContext() then
				Logger.info("[Register] 王国竞技场前离开广场")
				if not SquareTask.leaveForOtherTask() then
					Logger.warn("[Register] 离开广场失败，跳过王国竞技场")
					return
				end
			end
			Logger.info("[Register] 开始王国竞技场任务")
			ArenaTask.run()
		end)

	Scheduler.add("梦幻繁星岛",
		function()
			local starlight = UserConfig.get("starlight")
			if not starlight or starlight.enabled ~= true then
				return false
			end
			if StarlightSession.isDoneToday() then
				return false
			end
			if not isMineSchedulerIdle() then
				updateMineWaitHud("矿山待执行")
				Logger.info("[Register] 矿山待执行，跳过梦幻繁星岛")
				return false
			end
			return true
		end,
		function()
			if SquareRoute.isSquareContext() then
				Logger.info("[Register] 梦幻繁星岛前离开广场")
				if not SquareTask.leaveForOtherTask() then
					Logger.warn("[Register] 离开广场失败，跳过梦幻繁星岛")
					return
				end
			end
			Logger.info("[Register] 开始梦幻繁星岛任务")
			StarlightTask.run()
		end)

	Scheduler.add("布谷鸟广场",
		function()
			local square = UserConfig.get("square")
			if not square.enabled then
				return false
			end
			if SquareSession.isDoneToday() then
				return false
			end
			if not isMineSchedulerIdle() then
				updateMineWaitHud("矿山待执行")
				Logger.info("[Register] 矿山待执行，跳过布谷鸟广场")
				return false
			end
			return true
		end,
		function()
			Logger.info("[Register] 开始布谷鸟广场任务")
			SquareTask.run()
		end)

	-- 脆饼: 洗脆饼词条
	Scheduler.add("洗脆饼词条",
		function()
			-- 1. 用户是否开启洗脆饼词条功能
			if not UserConfig.get("biscuit").enabled then
				return false
			end

			return true
		end,
		function()
			if SquareRoute.isSquareContext() then
				Logger.info("[Register] 洗脆饼前离开广场")
				if not SquareTask.leaveForOtherTask() then
					Logger.warn("[Register] 离开广场失败，跳过洗脆饼")
					return
				end
			end
			if BiscuitTask.run() then
				Logger.info("[Register] 洗脆饼完成")
			end
		end)

	--[===[	-- 竞技场：直接传 Flows 函数引用
	Scheduler.add("arena", function()
	return Store.get("arena_count", 0) < 3
	end, Flows.arena)
	
	-- 邮件：直接点击，不走状态机
	Scheduler.add("mail", function()
	return not Store.get("mail_done", false)
	end, function()
	tap(Pages.mail.open)
	sleep(800)
	tap(Pages.mail.get_all)
	sleep(800)
	tap(Pages.mail.close)
	Store.set("mail_done", true)
	end)
	
	-- 公会：周一才执行
	Scheduler.add("guild", function()
	local is_monday = os.date("%w") == "1"
	return is_monday and not Store.get("guild_done", false)
	end, Flows.guild)]===]

	Logger.info(string.format(
		"[Register] 注入完成 | 守卫 %d 个 任务 %d 个" ,
		Guard.trapCount() , Scheduler.count()
	))
end

return Register
