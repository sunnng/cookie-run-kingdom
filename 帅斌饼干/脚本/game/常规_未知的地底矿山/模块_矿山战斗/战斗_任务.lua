--[[
模块: 矿山战斗任务
路径: game.常规_未知的地底矿山.模块_矿山战斗.战斗_任务
功能: 状态机驱动矿山战斗流程：导航→扫描快转/战斗卡→快转→结算→回城
依赖: core.state-machine, lib.user-config, lib.status-hud, core.guard,
      game.常规_未知的地底矿山.模块_矿山战斗.战斗_页面,
      game.常规_未知的地底矿山.矿山首页_页面,
      game.常规_未知的地底矿山.矿山_路由,
      game.通用_王国.页面
--]]

local Logger = require("lib.logger")
local StateMachine = require("core.state-machine")
local UserConfig = require("lib.user-config")
local StatusHud = require("lib.status-hud")
local Guard = require("core.guard")

local Route = require("game.常规_未知的地底矿山.矿山_路由")
local BattlePage = require("game.常规_未知的地底矿山.模块_矿山战斗.战斗_页面")
local MineHomePage = require("game.常规_未知的地底矿山.矿山首页_页面")
local KingdomPage = require("game.通用_王国.页面")

local BattleTask = {}
local BattleSession = require("game.常规_未知的地底矿山.模块_矿山战斗.战斗_会话")

local TAG = "[矿山战斗]"

--- @return table<string, boolean>
local function resolveTargetSoulStones()
	local cfg = UserConfig.get("mine")
	local keys = cfg.battleSoulStones
	if type(keys) ~= "table" or #keys == 0 then
		return {}
	end
	local out = {}
	for _ , name in ipairs(keys) do
		out[name] = true
	end
	return out
end

--- @param sm table
--- @param patch table|nil
local function updateHud(sm , patch)
	local opts = {
		state = sm:getState() ,
		retry = sm.retries > 0 and sm.retries or nil ,
	}
	if patch then
		for k , v in pairs(patch) do
			opts[k] = v
		end
	end
	StatusHud.setMineBattle(opts)
end

local function detect(sm)
	updateHud(sm , { extra = "识别页面…" })

	if BattlePage.isBattlePage() then
		Logger.info(TAG .. " [detect] 在矿山战斗页 → battleLoop")
		return "battleLoop"
	elseif MineHomePage.isCurrent() then
		Logger.info(TAG .. " [detect] 在矿山首页 → navigate")
		return "navigate"
	elseif KingdomPage.isKingdomHome() then
		Logger.info(TAG .. " [detect] 在王国首页 → navigate")
		return "navigate"
	end

	Logger.warn(TAG .. " [detect] 页面识别失败")
	return false , "矿山战斗[detect] 页面识别失败"
end

local function navigate(sm)
	if KingdomPage.isKingdomHome() then
		updateHud(sm , { extra = "王国→矿山首页" })
		Logger.info(TAG .. " [navigate] 王国首页 → 矿山首页")
		if not Route.kingdomHomeToMineHome() then
			Logger.warn(TAG .. " [navigate] 王国→矿山首页失败")
			return StateMachine.RETRY
		end
		return StateMachine.KEEP
	end

	if MineHomePage.isCurrent() then
		updateHud(sm , { extra = "矿山首页→战斗页" })
		Logger.info(TAG .. " [navigate] 矿山首页 → 战斗页")
		MineHomePage.tapBattleBtn()
		if BattlePage.waitBattlePage(30000 , 500) then
			return "battleLoop"
		end
		Logger.warn(TAG .. " [navigate] 等待矿山战斗页超时")
		return StateMachine.RETRY
	end

	if BattlePage.isBattlePage() then
		return "battleLoop"
	end

	Logger.warn(TAG .. " [navigate] 当前页面未知，无法导航")
	return false , "矿山战斗[navigate] 当前页面未知"
end

--- 快转流程
--- @param sm table
local function quickBattle(sm)
	updateHud(sm , { extra = "快转弹窗…" })

	local point = sm.ctx.quickBattlePoint
	if not point then
		Logger.warn(TAG .. " [quickBattle] 缺少快转按钮坐标")
		return "exit"
	end

	BattlePage.tapQuickBattleButton(point.x , point.y)
	if not BattlePage.waitQuickBattleDialog(10000 , 500) then
		Logger.warn(TAG .. " [quickBattle] 快转弹窗未出现")
		return StateMachine.RETRY
	end

	Guard.sleep(500)
	local used , owned , raw = BattlePage.readClockCount()
	Logger.info(string.format(TAG .. " [quickBattle] 发条 %s (used=%s owned=%s)" ,
		tostring(raw) , tostring(used) , tostring(owned)))

	if not used or not owned then
		Logger.warn(TAG .. " [quickBattle] 发条数量读取失败，取消快转")
		BattlePage.tapQuickBattleCancel()
		BattlePage.waitQuickBattleDialogGone(5000)
		return "exit"
	end

	if used > owned then
		Logger.info(TAG .. " [quickBattle] 发条不足，取消快转")
		BattlePage.tapQuickBattleCancel()
		BattlePage.waitQuickBattleDialogGone(5000)
		return "exit"
	end

	Logger.info(TAG .. " [quickBattle] 发条充足，确认快转")
	BattlePage.tapQuickBattleConfirm()

	if BattlePage.tapSettleUntilBattlePage() then
		Logger.info(TAG .. " [quickBattle] 快转结算完成 → battleLoop")
		return "battleLoop"
	end

	Logger.warn(TAG .. " [quickBattle] 结算后未回到战斗页")
	return StateMachine.RETRY
end

--- 战斗卡扫描与迭代
--- @param sm table
--- @param targetNames table<string, boolean>
local function scanAndIterateCards(sm , targetNames)
	local cards = BattlePage.findBattleCards()
	Logger.info(TAG .. " [battleLoop] 战斗卡数量=" .. #cards)

	if #cards == 1 then
		Logger.info(TAG .. " [battleLoop] 仅1张战斗卡，退出")
		return "exit"
	end

	if #cards > 1 then
		for i = 2 , #cards do
			updateHud(sm , { extra = string.format("点击战斗卡 %d/%d" , i , #cards) })
			local card = cards[i]
			Logger.info(string.format(TAG .. " [battleLoop] 点击第 %d/%d 张战斗卡 (%d,%d)" ,
				i , #cards , card.x , card.y))
			BattlePage.tapBattleCard(card)
			Guard.sleep(800)

			local matched = BattlePage.recognizeSoulStoneType(targetNames)
			if matched then
				Logger.info(TAG .. " [battleLoop] 灵魂石匹配: " .. matched)
				local qx , qy = BattlePage.findQuickBattleButton()
				if qx then
					sm.ctx.quickBattlePoint = { x = qx , y = qy }
					return "quickBattle"
				end
				Logger.warn(TAG .. " [battleLoop] 灵魂石匹配但快转按钮消失，继续迭代")
			else
				Logger.debug(TAG .. " [battleLoop] 灵魂石不匹配，继续下一张")
			end
		end
	end

	if #cards >= 5 then
		updateHud(sm , { extra = "翻页检查…" })
		Logger.info(TAG .. " [battleLoop] 战斗卡≥5，执行翻页检查")
		local isLastPage = BattlePage.swipeUpAndCheckLastPage()
		if isLastPage then
			Logger.info(TAG .. " [battleLoop] 已到末页，退出")
			return "exit"
		end
		Logger.info(TAG .. " [battleLoop] 未到末页，重新扫描战斗卡")
		return "battleLoop"
	end

	Logger.info(TAG .. " [battleLoop] 战斗卡<5且无可操作项，退出")
	return "exit"
end

local function battleLoop(sm)
	updateHud(sm , { extra = "扫描快转…" })

	if not BattlePage.isBattlePage() then
		Logger.warn(TAG .. " [battleLoop] 当前不在战斗页")
		return StateMachine.RETRY
	end

	local targetNames = resolveTargetSoulStones()

	-- 1. 优先处理当前页可见的快转
	local qx , qy = BattlePage.findQuickBattleButton()
	if qx then
		Logger.info(TAG .. " [battleLoop] 发现快转按钮")
		local matched = BattlePage.recognizeSoulStoneType(targetNames)
		if matched then
			Logger.info(TAG .. " [battleLoop] 快转灵魂石匹配: " .. matched)
			sm.ctx.quickBattlePoint = { x = qx , y = qy }
			return "quickBattle"
		end
		Logger.info(TAG .. " [battleLoop] 快转灵魂石不匹配，扫描战斗卡")
		return scanAndIterateCards(sm , targetNames)
	end

	-- 2. 无快转按钮，扫描战斗卡
	Logger.info(TAG .. " [battleLoop] 无快转按钮，扫描战斗卡")
	return scanAndIterateCards(sm , targetNames)
end

local function exitTask(sm)
	updateHud(sm , { extra = "返回矿山首页…" })

	if BattlePage.isBattlePage() then
		BattlePage.tapBackBtn()
		if not MineHomePage.wait(30000) then
			Logger.warn(TAG .. " [exit] 返回矿山首页超时")
			return StateMachine.RETRY
		end
	end

	updateHud(sm , { extra = "返回王国首页…" })
	if MineHomePage.isCurrent() then
		MineHomePage.tapBack()
		if not KingdomPage.wait(30000) then
			Logger.warn(TAG .. " [exit] 返回王国首页超时")
			return StateMachine.RETRY
		end
	end

	if KingdomPage.isKingdomHome() then
		Logger.info(TAG .. " [exit] 已回到王国首页")
		return StateMachine.DONE
	end

	Logger.warn(TAG .. " [exit] 退出链路失败")
	return StateMachine.RETRY
end

local handlers = {
	detect = detect ,
	navigate = navigate ,
	battleLoop = battleLoop ,
	quickBattle = quickBattle ,
	exit = exitTask ,
}

function BattleTask.run()
	local cfg = UserConfig.get("mine")
	if cfg.battleEnabled ~= true then
		Logger.info(TAG .. " 任务未启用，跳过")
		return false
	end

	local targetNames = resolveTargetSoulStones()
	local targetList = {}
	for name , _ in pairs(targetNames) do
		targetList[#targetList + 1] = name
	end

	if #targetList == 0 then
		Logger.warn(TAG .. " 未配置目标灵魂石，跳过战斗任务")
		return false
	end

	Logger.info(string.format(
		TAG .. " 任务启动 | battleEnabled=%s targetSoulStones=%s" ,
		tostring(cfg.battleEnabled) ,
		table.concat(targetList , ",")
	))

	-- 记录本次战斗时间，用于控制检测频率
	BattleSession.recordBattle()

	StatusHud.setMineBattle({
		state = "detect" ,
		extra = "任务启动" ,
	})

	local ctx = {
		quickBattlePoint = nil ,
	}

	local stateMachine = StateMachine.new()
	stateMachine:init("detect" , {
		maxRetry = 3 ,
		timeout = 1800 ,
		retryIntervalMs = 1000 ,
	})
	stateMachine.ctx = ctx

	local ok , err = stateMachine:run(handlers , {
		interval = 500 ,
		guard = Guard.check ,
		label = "矿山战斗" ,
	})
	if ok then
		Logger.info(TAG .. " 任务完成")
	else
		StatusHud.setMineBattle({
			extra = "失败: " .. tostring(err) ,
		})
		Logger.warn(TAG .. " 任务结束：" .. tostring(err))
	end
	return ok
end

return BattleTask
