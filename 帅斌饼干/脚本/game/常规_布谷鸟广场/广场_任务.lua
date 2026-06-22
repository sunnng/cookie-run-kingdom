--[[
模块: 布谷鸟广场任务
路径: game.常规_布谷鸟广场.广场_任务
功能: 广场页 ↔ 离开弹窗；弹窗内检查完成状态 / 奖励数量
--]]

local Logger = require("lib.logger")
local StatusHud = require("lib.status-hud")
local UserConfig = require("lib.user-config")
local Guard = require("core.guard")
local KingdomPage = require("game.通用_王国.页面")
local SquarePage = require("game.常规_布谷鸟广场.广场_页面")
local SquareRoute = require("game.常规_布谷鸟广场.广场_路由")
local SquareSession = require("game.常规_布谷鸟广场.广场_会话")

local SquareTask = {}
local TAG = "[布谷鸟广场任务]"
local MIN_STAY_SEC = 60

local function cfg()
	return UserConfig.get("square")
end

local function dailyCap()
	return cfg().dailyCap or 240
end

local function staySec()
	return math.max(MIN_STAY_SEC , cfg().checkIntervalSec or MIN_STAY_SEC)
end

local function maxChunkSec()
	return cfg().chunkSec or 10
end

local function stayProgressText()
	local required = staySec()
	local rem = SquareSession.stayRemaining(required)
	if rem <= 0 then
		return "可开弹窗查看奖励"
	end
	local elapsed = math.max(0 , required - rem)
	return string.format("有效停留 %ds/%ds" , elapsed , required)
end

local function ensureSquarePage()
	if SquarePage.isCurrent() or SquarePage.isLeaveDialog() then
		return true
	end
	if KingdomPage.isKingdomHome() then
		return SquareRoute.kingdomToSquare()
	end
	Logger.warn(TAG .. " 当前界面未知，无法进入广场")
	return false
end

local function openLeaveDialog()
	if SquarePage.isLeaveDialog() then
		SquareSession.startStay()
		return true
	end
	if not ensureSquarePage() then
		SquareSession.pauseStay()
		return false
	end
	SquareSession.startStay()
	return SquareRoute.openLeaveDialog()
end

local function finishToday(reason)
	Logger.info(TAG .. " 今日广场任务结束: " .. tostring(reason))
	StatusHud.setTask("布谷鸟广场" , "今日已完成")
	SquareSession.pauseStay()
	if not SquareRoute.leaveDialogToKingdom(30000) then
		return false
	end
	SquareSession.markDoneToday()
	return true
end

local function claimAndFinish()
	Logger.info(TAG .. " 奖励已达标，点击一次领回")
	StatusHud.setTask("布谷鸟广场" , "一次领回…")
	if not SquarePage.isLeaveDialog() and not openLeaveDialog() then
		return false
	end
	SquarePage.tapClaimAll(500)
	Guard.sleep(1500 , 500)
	SquarePage.tapUtilDialog()
	return finishToday("已领取奖励")
end

local function waitAccumulationChunk()
	if not ensureSquarePage() then
		SquareSession.pauseStay()
		return false
	end
	if SquarePage.isLeaveDialog() then
		SquarePage.tapCloseDialog(1000)
		Guard.sleep(800 , 400)
		if not SquarePage.isCurrent() then
			return false
		end
	end
	
	SquareSession.startStay()
	local remaining = SquareSession.stayRemaining(staySec())
	if remaining <= 0 then
		Logger.info(TAG .. " 有效停留已满 " .. staySec() .. " 秒，打开离开弹窗检查")
		StatusHud.setTask("布谷鸟广场" , "检查奖励…")
		return openLeaveDialog() and SquareTask.handleLeaveDialog()
	end
	
	local chunk = math.min(remaining , maxChunkSec())
	StatusHud.countdownSleep(
	chunk ,
	"wait" ,
	"布谷鸟广场" ,
	function()
		return stayProgressText()
	end ,
	math.min(5 , chunk)
	)
	return true
end

function SquareTask.handleLeaveDialog()
	if not SquarePage.isLeaveDialog() then
		Logger.warn(TAG .. " handleLeaveDialog 调用时不在离开弹窗")
		return false
	end
	
	SquareSession.startStay()
	Guard.sleep(500 , 250)
	
	if SquarePage.isFinishOcr() then
		return finishToday("isFinishOcr=最大")
	end
	
	local pending , total , sum = SquarePage.readRewardSum()
	if not sum then
		Guard.sleep(1000 , 500)
		pending , total , sum = SquarePage.readRewardSum()
	end
	if not sum then
		Logger.warn(TAG .. " 无法识别奖励数量")
		return false
	end
	
	StatusHud.setTask("布谷鸟广场" , string.format("%d+%d=%d / %d" , pending , total , sum , dailyCap()))
	if sum >= dailyCap() then
		return claimAndFinish()
	end
	
	Logger.info(TAG .. string.format(" 未达领取条件 %d/%d，返回广场继续挂机" , sum , dailyCap()))
	SquarePage.tapCloseDialog(1000)
	Guard.sleep(800 , 400)
	SquareSession.markCheckedToday()
	SquareSession.resetStayTimer()
	return waitAccumulationChunk()
end

--- 其它任务插队：回王国主城，保留本轮有效停留进度
--- @return boolean
function SquareTask.leaveForOtherTask()
	SquareSession.pauseStay()
	if KingdomPage.isKingdomHome() then
		return true
	end
	if SquarePage.isLeaveDialog() then
		return SquareRoute.leaveDialogToKingdom(30000)
	end
	if SquarePage.isCurrent() then
		SquarePage.tapBack(1000)
		if SquarePage.waitLeaveDialog(8000) then
			return SquareRoute.leaveDialogToKingdom(30000)
		end
	end
	return SquareRoute.leaveDialogToKingdom(30000)
end

--- @return boolean
function SquareTask.run()
	if SquareSession.isDoneToday() then
		Logger.info(TAG .. " 今日已完成，跳过")
		return true
	end
	
	SquareSession.ensure()
	StatusHud.setTask("布谷鸟广场" , "执行中…")
	
	if SquareSession.hasCheckedToday() then
		return waitAccumulationChunk()
	end

	if not openLeaveDialog() then
		return false
	end
	return SquareTask.handleLeaveDialog()
end

return SquareTask
