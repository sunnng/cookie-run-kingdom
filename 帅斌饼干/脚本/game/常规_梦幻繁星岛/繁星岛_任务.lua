--[[
模块: 梦幻繁星岛任务
路径: game.常规_梦幻繁星岛.繁星岛_任务
功能: 按流程图完成每日签到与任务领奖
依赖: core.state-machine, core.guard, lib.logger, lib.status-hud
       game.常规_梦幻繁星岛.繁星岛_页面
       game.常规_梦幻繁星岛.繁星岛_路由
       game.常规_梦幻繁星岛.繁星岛_会话
--]]

local Logger = require("lib.logger")
local StateMachine = require("core.state-machine")
local Guard = require("core.guard")
local StatusHud = require("lib.status-hud")

local StarlightPage = require("game.常规_梦幻繁星岛.繁星岛_页面")
local StarlightRoute = require("game.常规_梦幻繁星岛.繁星岛_路由")
local StarlightSession = require("game.常规_梦幻繁星岛.繁星岛_会话")
local KingdomPage = require("game.通用_王国.页面")

local Task = {}
local TAG = "[梦幻繁星岛任务]"

local function updateHud(state)
	StatusHud.setTask("梦幻繁星岛" , state or "执行中…")
end

local function check(sm)
	if StarlightSession.isDoneToday() then
		Logger.info(TAG .. " 今日已执行，跳过")
		return StateMachine.DONE
	end
	return "detect"
end

local function detect(sm)
	if StarlightPage.isHomePage() then
		Logger.info(TAG .. " [detect] 当前在梦幻繁星岛首页")
		return "openManual"
	end
	if StarlightPage.isManualPage() then
		Logger.info(TAG .. " [detect] 当前在航海手册页")
		return "enterIsland"
	end
	if StarlightPage.isVanillaIslandPage() then
		Logger.info(TAG .. " [detect] 当前在纯香草小岛页")
		return "returnFromIsland"
	end
	if StarlightPage.isTaskPage() then
		Logger.info(TAG .. " [detect] 当前在任务页")
		return "claimTask"
	end
	Logger.info(TAG .. " [detect] 不在已知页面，尝试导航")
	return "navigate"
end

local function navigate(sm)
	updateHud("导航到活动…")
	if StarlightRoute.ensureStarlightHome() then
		return "openManual"
	end
	Logger.warn(TAG .. " [navigate] 导航到梦幻繁星岛首页失败")
	return false , "导航到梦幻繁星岛首页失败"
end

local function openManual(sm)
	updateHud("打开航海手册…")
	if not StarlightPage.tapSailingManual() then
		return StateMachine.RETRY
	end
	if StarlightPage.waitManualPage(10000) then
		return "enterIsland"
	end
	Logger.warn(TAG .. " [openManual] 等待航海手册页超时")
	return StateMachine.RETRY
end

local function enterIsland(sm)
	updateHud("进入纯香草小岛…")
	if not StarlightPage.tapLoginIsland() then
		return StateMachine.RETRY
	end
	if StarlightPage.waitVanillaIslandPage(10000) then
		return "returnFromIsland"
	end
	Logger.warn(TAG .. " [enterIsland] 等待纯香草小岛页超时")
	return StateMachine.RETRY
end

local function returnFromIsland(sm)
	updateHud("返回首页…")
	if not StarlightPage.tapBackFromVanilla() then
		return StateMachine.RETRY
	end
	if StarlightPage.waitHomePage(10000) then
		return "openTask"
	end
	Logger.warn(TAG .. " [returnFromIsland] 等待首页超时")
	return StateMachine.RETRY
end

local function openTask(sm)
	updateHud("打开任务页…")
	if not StarlightPage.tapTaskBtn() then
		return StateMachine.RETRY
	end
	if StarlightPage.waitTaskPage(10000) then
		return "claimTask"
	end
	Logger.warn(TAG .. " [openTask] 等待任务页超时")
	return StateMachine.RETRY
end

local function claimTask(sm)
	updateHud("领取任务奖励…")
	local x , y = StarlightPage.findClaimableBtn()
	if x then
		Logger.info(TAG .. " [claimTask] 发现可领奖按钮 (" .. x .. "," .. y .. ")")
		StarlightPage.tapClaimableBtn(x , y)
		Guard.sleep(2000 , 500)
		StarlightPage.dismissRewardPopupIfNeeded()
	else
		Logger.info(TAG .. " [claimTask] 无可领奖按钮")
	end

	StarlightSession.markDoneToday()
	return "finish"
end

local function finish(sm)
	updateHud("返回首页…")
	if not StarlightPage.tapBackFromTask() then
		return StateMachine.RETRY
	end
	if not StarlightPage.waitHomePage(10000) then
		Logger.warn(TAG .. " [finish] 等待首页超时")
		return StateMachine.RETRY
	end

	updateHud("返回王国…")
	if not StarlightPage.tapBackToKingdom() then
		return StateMachine.RETRY
	end
	if KingdomPage.wait(10000) then
		Logger.info(TAG .. " 任务完成")
		return StateMachine.DONE
	end
	Logger.warn(TAG .. " [finish] 等待王国首页超时")
	return StateMachine.RETRY
end

local handlers = {
	check = check ,
	detect = detect ,
	navigate = navigate ,
	openManual = openManual ,
	enterIsland = enterIsland ,
	returnFromIsland = returnFromIsland ,
	openTask = openTask ,
	claimTask = claimTask ,
	finish = finish ,
}

function Task.run()
	Logger.info(TAG .. " 任务启动")
	updateHud("启动…")

	local sm = StateMachine.new()
	sm:init("check" , {
		maxRetry = 3 ,
		timeout = 180 ,
		retryIntervalMs = 1000 ,
	})

	local ok , err = sm:run(handlers , {
		interval = 500 ,
		guard = Guard.check ,
		label = "梦幻繁星岛" ,
	})

	if ok then
		Logger.info(TAG .. " 任务完成")
		updateHud("今日已完成")
	else
		Logger.warn(TAG .. " 任务结束：" .. tostring(err))
		updateHud("失败: " .. tostring(err))
	end
	return ok
end

return Task
