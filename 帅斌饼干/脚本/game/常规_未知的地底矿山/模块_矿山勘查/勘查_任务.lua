local Logger = require("lib.logger")
local StateMachine = require("core.state-machine")
local UserConfig = require("lib.user-config")
local StatusHud = require("lib.status-hud")

local Route = require("game.常规_未知的地底矿山.矿山_路由")
local MineVenturePage = require("game.常规_未知的地底矿山.模块_矿山勘查.勘查_页面")
local MineHomePage = require("game.常规_未知的地底矿山.矿山首页_页面")
local KingdomPage = require("game.通用_王国.页面")
local Session = require("game.常规_未知的地底矿山.模块_矿山勘查.勘查_会话")
local Guard = require("core.guard")

local MineVentureTask = {}

local TAG = "[矿山勘查]"

--- 刷新顶部 HUD（从 sm.ctx / 状态机读取调试字段）
--- @param sm table
--- @param patch table|nil 覆盖字段
local function updateHud(sm , patch)
	local ctx = sm.ctx
	local cfg = ctx.mineVentureCfg
	local opts = {
		state = sm:getState() ,
		floor = ctx.lastFloor ,
		gap = ctx.lastGap ,
		target = cfg.targetFloor ,
		farGap = cfg.farGap ,
		retry = sm.retries > 0 and sm.retries or nil ,
	}
	if ctx.nextOcrPollAt then
		opts.ocrInSec = ctx.nextOcrPollAt - os.time()
	end
	local farRemain = Session.restoreProgress()
	if farRemain > 0 then
		opts.farWaitSec = farRemain
	end
	if patch then
		for k , v in pairs(patch) do
			opts[k] = v
		end
	end
	StatusHud.setMineSurvey(opts)
end

--- 初始状态恢复：根据持久化进度和当前页面决定起点
--- @param cfg table mineVentureCfg
--- @return string|nil initialState  nil 表示本轮不应运行（仍在远距等待期）
--- @return number remainSec          远距剩余秒数（initialState 为 nil 时有意义）
local function resolveInitialState(cfg)
	-- 1. 远距等待未到期：本轮不运行（register condition 已挡，此处双保险）
	local remain = Session.restoreProgress()
	if remain > 0 then
		return nil , remain
	end
	
	-- 2. 按当前页面决定起点
	if MineVenturePage.isMineVentureDomain() then
		Logger.info(TAG .. " 初始状态: prepare（已在勘查域）")
		return "prepare" , 0
	end
	if MineHomePage.isCurrent() or KingdomPage.isKingdomHome() then
		Logger.info(TAG .. " 初始状态: navigate（在矿山首页或王国首页）")
		return "navigate" , 0
	end
	
	-- 3. 未知页面：从 detect 起步尝试识别
	Logger.info(TAG .. " 初始状态: detect（页面未知）")
	return "detect" , 0
end

local handlers = {
	detect = function (sm)
		updateHud(sm , { extra = "识别页面…" })
		Logger.debug(TAG .. " [detect] 识别当前页面")
		if MineVenturePage.isMineVentureDomain() then
			Logger.info(TAG .. " [detect] 在勘查域 → prepare")
			return "prepare"
		elseif KingdomPage.isKingdomHome() or MineHomePage.isCurrent() then
			Logger.info(TAG .. " [detect] 在王国/矿山首页 → navigate")
			return "navigate"
		else
			Logger.warn(TAG .. " [detect] 页面识别失败")
			return false , "矿山勘查[detect] 页面识别失败"
		end
	end ,
	
	navigate = function (sm)
		local step
		if KingdomPage.isKingdomHome() then
			step = "王国→矿山"
		elseif MineHomePage.isCurrent() then
			step = "矿山→勘查"
		elseif MineVenturePage.isMineVentureDomain() then
			step = "已到勘查域"
		else
			step = "定位中"
		end
		updateHud(sm , { extra = step })
		Logger.debug(TAG .. " [navigate] 导航中")
		if KingdomPage.isKingdomHome() then
			Logger.info(TAG .. " [navigate] 王国首页 → 矿山首页")
			Route.kingdomHomeToMineHome()
		elseif MineHomePage.isCurrent() then
			Logger.info(TAG .. " [navigate] 矿山首页 → 进入勘查")
			MineHomePage.tapVenture()
		elseif MineVenturePage.isMineVentureDomain() then
			Logger.info(TAG .. " [navigate] 已进入勘查域 → prepare")
			Guard.sleep(1000)
			return "prepare"
		end
		-- 本步导航已执行但尚未到达目标页：保持 navigate，不计入重试
		return StateMachine.KEEP
	end ,
	
	prepare = function (sm)
		if MineVenturePage.isRunning() then
			updateHud(sm , { extra = "勘查进行中" })
		else
			updateHud(sm , { extra = "启动 setup…" })
		end
		Logger.debug(TAG .. " [prepare] 准备勘查")
		if MineVenturePage.isRunning() then
			Logger.info(TAG .. " [prepare] 勘查进行中 → running")
			return "running"
		end
		
		if MineVenturePage.setup() then
			local waitSec = sm.ctx.mineVentureCfg.farWaitSec
			Session.enterFarWait(waitSec)
			updateHud(sm , {
				farWaitSec = waitSec ,
				extra = "已启动 回城" ,
			})
			Logger.info(TAG .. " [prepare] setup 完成 → farWait")
			return "farWait"
		end
		
		Logger.warn(TAG .. " [prepare] setup 执行失败")
		return false , "矿山勘查[prepare] setup 执行失败"
	end ,
	
	running = function (sm)
		updateHud(sm , { extra = "OCR 读层…" })
		Logger.debug(TAG .. " [running] 读取当前层数")
		local currentFloor = MineVenturePage.getCurrentFloor()
		if not currentFloor then
			updateHud(sm , { extra = "OCR 失败" })
			Logger.warn(TAG .. " [running] OCR 未识别层数，重试")
			return StateMachine.RETRY
		end
		
		local cfg = sm.ctx.mineVentureCfg
		local targetFloor = cfg.targetFloor
		local floorDiff = math.abs(targetFloor - currentFloor)
		sm.ctx.lastFloor = currentFloor
		sm.ctx.lastGap = floorDiff
		
		Logger.info(string.format(
		TAG .. " [running] 当前层:%d 目标:%d 阈值:%d 轮询:%ds 远距等待:%ds" ,
		currentFloor , targetFloor , cfg.farGap , cfg.ocrPollSec , cfg.farWaitSec
		))
		
		if currentFloor >= targetFloor then
			updateHud(sm , { extra = "已达标" })
			Logger.info(TAG .. " [running] 已达标 → settle")
			return "settle"
		elseif floorDiff > cfg.farGap then
			Session.enterFarWait(cfg.farWaitSec)
			updateHud(sm , {
				farWaitSec = cfg.farWaitSec ,
				extra = string.format("远距 差%d>%d" , floorDiff , cfg.farGap) ,
			})
			Logger.info(string.format(
			TAG .. " [running] 远距(差%d>%d) → farWait，回城等待 %ds" ,
			floorDiff , cfg.farGap , cfg.farWaitSec
			))
			return "farWait"
		else
			updateHud(sm , {
				extra = string.format("近距 差%d≤%d" , floorDiff , cfg.farGap) ,
			})
			Logger.info(string.format(
			TAG .. " [running] 近距(差%d<=%d) → polling" ,
			floorDiff , cfg.farGap
			))
			return "polling"
		end
	end ,
	
	polling = function (sm)
		local cfg = sm.ctx.mineVentureCfg
		
		-- 首次进入 polling，设置下次 OCR 时间
		if not sm.ctx.nextOcrPollAt then
			sm.ctx.nextOcrPollAt = os.time() + cfg.ocrPollSec
			Logger.debug(string.format(
			TAG .. " [polling] 首次进入，下次 OCR 在 %ds 后" , cfg.ocrPollSec
			))
		end
		
		local ocrIn = sm.ctx.nextOcrPollAt - os.time()
		if os.time() >= sm.ctx.nextOcrPollAt then
			updateHud(sm , { extra = "OCR 轮询…" })
			local currentFloor = MineVenturePage.getCurrentFloor()
			sm.ctx.nextOcrPollAt = os.time() + cfg.ocrPollSec
			if currentFloor then
				sm.ctx.lastFloor = currentFloor
				sm.ctx.lastGap = math.abs(cfg.targetFloor - currentFloor)
			end
			if currentFloor and currentFloor >= cfg.targetFloor then
				updateHud(sm , { extra = "轮询达标" })
				Logger.info(string.format(
				TAG .. " [polling] 达标 当前层:%d ≥ 目标:%d → settle" ,
				currentFloor , cfg.targetFloor
				))
				return "settle"
			elseif not currentFloor then
				updateHud(sm , { extra = "OCR 失败" })
				Logger.warn(TAG .. " [polling] OCR 未识别层数，重试")
				return StateMachine.RETRY
			else
				updateHud(sm , {
					floor = sm.ctx.lastFloor ,
					gap = sm.ctx.lastGap ,
					ocrInSec = cfg.ocrPollSec ,
					extra = "未达标" ,
				})
				Logger.debug(string.format(
				TAG .. " [polling] 当前层:%s 目标:%d，继续等待" ,
				tostring(currentFloor) , cfg.targetFloor
				))
				return StateMachine.KEEP
			end
		else
			updateHud(sm , {
				ocrInSec = ocrIn ,
				extra = "等待 OCR" ,
			})
			Logger.debug(TAG .. " [polling] 等待下次 OCR 轮询点")
			return StateMachine.KEEP
		end
	end ,
	
	settle = function (sm)
		updateHud(sm , { extra = "停止并结算…" })
		Logger.info(TAG .. " [settle] 停止勘查并结算")
		if MineVenturePage.stopVenture() then
			updateHud(sm , { extra = "结算完成" })
			Logger.info(TAG .. " [settle] 结算完成 → detect（进入下一轮识别）")
			return "detect"
		end
		updateHud(sm , { extra = "结算失败" })
		Logger.warn(TAG .. " [settle] 停止勘查失败")
		return StateMachine.RETRY
	end ,
	
	farWait = function (sm)
		updateHud(sm , { extra = "回城中…" })
		Logger.info(TAG .. " [farWait] 导航回王国，本轮结束（等待期满后由调度再次拉起）")
		Route.mineVentureToMineHome()
		Route.mineHomeToKingdom()
		local remain = Session.restoreProgress()
		updateHud(sm , {
			state = "idle" ,
			farWaitSec = remain > 0 and remain or sm.ctx.mineVentureCfg.farWaitSec ,
			extra = "本轮结束" ,
		})
		return StateMachine.DONE
	end ,
}

function MineVentureTask.run()
	local cfg = UserConfig.get("mine")
	Logger.info(string.format(
	TAG .. " 任务启动 | 目标层:%d 近距阈值:%d 轮询:%ds 远距等待:%ds" ,
	cfg.targetFloor , cfg.farGap , cfg.ocrPollSec , cfg.farWaitSec
	))
	
	-- 初始状态恢复：远距等待期内直接返回，否则按页面决定起点
	local initialState , remain = resolveInitialState(cfg)
	if not initialState then
		StatusHud.setMineSurvey({
			state = "idle" ,
			target = cfg.targetFloor ,
			farGap = cfg.farGap ,
			farWaitSec = remain ,
			extra = "远距等待中" ,
		})
		Logger.info(string.format(TAG .. " 远距等待中，剩余 %ds，本轮跳过" , remain))
		return false
	end
	
	StatusHud.setMineSurvey({
		state = initialState ,
		target = cfg.targetFloor ,
		farGap = cfg.farGap ,
		cfgHint = string.format("轮询%ds 远距%ds" , cfg.ocrPollSec , cfg.farWaitSec) ,
		extra = "任务启动" ,
	})
	
	local ctx = {
		mineVentureCfg = cfg ,
		nextOcrPollAt = nil ,
		lastFloor = nil ,
		lastGap = nil ,
	}
	
	local stateMachine = StateMachine.new()
	stateMachine:init(initialState , {
		maxRetry = 3 ,
		timeout = 1800 ,
		retryIntervalMs = 1000 ,
	})
	stateMachine.ctx = ctx
	
	local ok , err = stateMachine:run(handlers , {
		interval = 500 ,
		guard = Guard.check ,
		label = "矿山勘查" ,
	})
	if ok then
		Logger.info(TAG .. " 任务完成")
	else
		StatusHud.setMineSurvey({
			target = cfg.targetFloor ,
			farGap = cfg.farGap ,
			farWaitSec = Session.restoreProgress() ,
			extra = "失败: " .. tostring(err) ,
		})
		Logger.warn(TAG .. " 任务结束：" .. tostring(err))
	end
	return ok
end

return MineVentureTask
