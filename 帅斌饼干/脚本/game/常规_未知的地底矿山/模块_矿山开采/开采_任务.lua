local Logger = require("lib.logger")
local StateMachine = require("core.state-machine")
local UserConfig = require("lib.user-config")
local StatusHud = require("lib.status-hud")

local Route = require("game.常规_未知的地底矿山.矿山_路由")
local MiningPage = require("game.常规_未知的地底矿山.模块_矿山开采.开采_页面")
local MineHomePage = require("game.常规_未知的地底矿山.矿山首页_页面")
local KingdomPage = require("game.通用_王国.页面")
local Guard = require("core.guard")
local MineFeatureLib = require("game.常规_未知的地底矿山.矿山_特征库")
local MiningSession = require("game.常规_未知的地底矿山.模块_矿山开采.开采_会话")

local MiningTask = {}

local TAG = "[矿山开采]"

local OreVeinCardsFeatures = MineFeatureLib.oreVeinCards()

local DEFAULT_CARD_PRIORITY = {
	"amberFossil" ,
	"sugarOre" ,
	"purpleFossil" ,
	"emeraldFossil" ,
	"flourStone" ,
}

--- @param def table|nil
--- @return boolean
local function isCardConfigured(def)
	return type(def) == "table" and def[1] ~= nil
end

--- @return string[]
local function resolveCardPriority()
	local cfg = UserConfig.get("mine")
	local keys = cfg.miningOreCards
	if type(keys) ~= "table" or #keys == 0 then
		keys = DEFAULT_CARD_PRIORITY
	end
	local out = {}
	for _ , key in ipairs(keys) do
		local def = OreVeinCardsFeatures[key]
		if isCardConfigured(def) then
			out[#out + 1] = key
		end
	end
	if #out == 0 then
		for _ , key in ipairs(DEFAULT_CARD_PRIORITY) do
			local def = OreVeinCardsFeatures[key]
			if isCardConfigured(def) then
				out[#out + 1] = key
			end
		end
	end
	return out
end

--- @param sm table
--- @param patch table|nil
local function updateHud(sm , patch)
	local ctx = sm.ctx
	local opts = {
		state = sm:getState() ,
		selected = ctx.selectedCards ,
		quota = ctx.quotaMax ,
		retry = sm.retries > 0 and sm.retries or nil ,
	}
	if patch then
		for k , v in pairs(patch) do
			opts[k] = v
		end
	end
	StatusHud.setMineMining(opts)
end

local function detect(sm)
	if MiningPage.isMiningPage() then
		return "miningPageScan"
	elseif MineHomePage.isCurrent() then
		return "precheck"
	elseif KingdomPage.isKingdomHome() then
		return "navigate"
	end
	
	Logger.warn(TAG .. " [detect] 页面识别失败")
	return false , "矿山开采[detect] 页面识别失败"
end

local function navigate(sm)
	updateHud(sm , { extra = "王国→矿山首页" })
	if Route.kingdomHomeToMineHome() then
		return "precheck"
	end
	
	Logger.warn(TAG .. " [navigate] 王国→矿山首页失败")
	return false , "矿山开采[navigate] 王国→矿山首页失败"
end

local function precheck(sm)
	updateHud(sm , { extra = "首页预检…" })
	
	if MineHomePage.hasMiningCompletedTask() then
		Logger.info(TAG .. " [precheck] 首页发现开采存在已完成开采任务 → 进入开采页")
	end
	
	MineHomePage.tapMining()
	if MineHomePage.waitGone() then
		Guard.sleep(1000)
		if MiningPage.isMiningPage() then
			return "miningPageScan"
		elseif MiningPage.isSettlementRoute() then
			return "confirmRewards"
		end
	end
	
	Logger.warn(TAG .. " [precheck] 未能进入开采页面")
	return StateMachine.RETRY
end

local function miningPageScan(sm)
	updateHud(sm , { extra = "扫描开采页面…" })
	
	-- 1. 选择可完成槽位
	if MiningPage.tapCompletedSlot() then
		return "confirmRewards"
	end
	
	-- 2. 选择可空闲槽位
	if sm.ctx.skipSelectOnce then
		sm.ctx.skipSelectOnce = nil
		Logger.info(TAG .. " [miningPageScan] 无可用矿卡可填栏位，跳过选卡")
	elseif MiningPage.tapFreeSlot() then
		Logger.info(TAG .. " [miningPageScan] 有空闲栏位 → selectMineCard")
		return "selectMineCard"
	end
	
	-- 3. 选择可开采槽位
	if MiningPage.tapReadySlot() then
		Logger.info(TAG .. " [miningPageScan] 有可开始矿卡 → startMining")
		return "startMining"
	end
	
	Logger.info(TAG .. " [miningPageScan] 无已完成/无空闲/无可开采栏位 → done")
	return "done"
end

local function confirmRewards(sm)
	updateHud(sm , { extra = "获得开采奖励, 点击画面继续…" })
	
	if MiningPage.tapUntilMatchMiningPage() then
		Guard.sleep(1000)
		Logger.info(TAG .. " [claimConfirm] 奖励已确认 → miningPageScan")
		return "miningPageScan"
	end
	
	Logger.warn(TAG .. " [claimConfirm] 确认奖励失败")
	return StateMachine.RETRY
end

local function startMining(sm)
	updateHud(sm , { extra = "开始开采矿卡" })
	
	if MiningPage.autoSelectCookieAndStart() then
		Guard.sleep(1500)
		if MiningPage.isSetup() then
			return StateMachine.RETRY
		else
			return "miningPageScan"
		end
	end
	
	Logger.warn(TAG .. " [startMining] 开采矿卡失败")
	return StateMachine.RETRY
end

local function selectMineCard(sm)
	updateHud(sm , { extra = "选择矿卡" })
	
	local initCur , initMax , initRaw = MiningPage.readChooseQuota()
	if not initCur or not initMax then
		Logger.warn(TAG .. " [selectMineCard] OCR 可选数量失败 raw=" .. tostring(initRaw))
		return StateMachine.RETRY
	end
	
	sm.ctx.quotaCur = initCur
	sm.ctx.quotaMax = initMax
	sm.ctx.selectedCards = initCur
	updateHud(sm , {
		selected = initCur ,
		quota = initMax ,
		extra = string.format("选卡 %d/%d" , initCur , initMax) ,
	})
	
	if initCur >= initMax then
		Logger.info(string.format(TAG .. " [selectMineCard] 初始已选满 %d/%d，直接确认" , initCur , initMax))
	else
		local cardPriority = resolveCardPriority()
		local direction = sm.ctx.cardSwipeDirection or "left"
		for _ , cardKey in ipairs(cardPriority) do
			local cur , max = MiningPage.readChooseQuota()
			if not cur or not max then
				Logger.warn(TAG .. " [selectMineCard] 切换目标前 OCR 失败")
				return StateMachine.RETRY
			end
			
			if cur >= max then
				break
			end
			
			local need = max - cur
			local cardDef = OreVeinCardsFeatures[cardKey]
			if isCardConfigured(cardDef) then
				Logger.info(string.format(
				TAG .. " [selectMineCard] 目标矿卡 %s 方向:%s 还需 %d 张" ,
				cardKey , direction , need
				))
				
				local got , exhausted = MiningPage.selectTargetCards(cardDef , need , direction)
				cur , max = MiningPage.readChooseQuota()
				if not cur or not max then
					Logger.warn(TAG .. " [selectMineCard] 选卡后 OCR 失败")
					return StateMachine.RETRY
				end
				
				sm.ctx.quotaCur = cur
				sm.ctx.quotaMax = max
				sm.ctx.selectedCards = cur
				updateHud(sm , {
					selected = cur ,
					quota = max ,
					extra = string.format("选卡 %d/%d (%s+%d)" , cur , max , cardKey , got or 0) ,
				})
				
				if cur >= max then
					Logger.info(string.format(TAG .. " [selectMineCard] 已选满 %d/%d" , cur , max))
					break
				end
				
				if exhausted or (got or 0) == 0 then
					if exhausted then
						direction = direction == "left" and "right" or "left"
						sm.ctx.cardSwipeDirection = direction
					end
					Logger.info(string.format(
					TAG .. " [selectMineCard] %s 已扫完/无新增（+%d），切换下一种，方向:%s" ,
					cardKey , got or 0 , direction
					))
				else
					Logger.warn(TAG .. " [selectMineCard] 有新增但未填满，重试当前选卡流程")
					return StateMachine.RETRY
				end
			else
				Logger.debug(TAG .. " [selectMineCard] 跳过未配置矿卡 " .. tostring(cardKey))
			end
		end
	end
	
	local finalCur , finalMax , finalRaw = MiningPage.readChooseQuota()
	if not finalCur or not finalMax then
		Logger.warn(TAG .. " [selectMineCard] 最终 OCR 校验失败 raw=" .. tostring(finalRaw))
		return StateMachine.RETRY
	end
	
	sm.ctx.quotaCur = finalCur
	sm.ctx.quotaMax = finalMax
	sm.ctx.selectedCards = finalCur
	updateHud(sm , {
		selected = finalCur ,
		quota = finalMax ,
		extra = string.format("选卡完成 %d/%d" , finalCur , finalMax) ,
	})
	
	if finalCur <= 0 then
		Logger.warn(TAG .. " [selectMineCard] 未选择任何矿卡，返回开采页")
		MiningPage.tapBackBtn()
		Guard.sleep(800)
		sm.ctx.skipSelectOnce = true
		return "miningPageScan"
	end
	
	if finalCur < finalMax then
		Logger.info(string.format(
		TAG .. " [selectMineCard] 配额未填满 %d/%d，确认已有选择" ,
		finalCur , finalMax
		))
	end
	
	updateHud(sm , { extra = "确认选卡…" })
	if not MiningPage.confirmCardSelection() then
		Logger.warn(TAG .. " [selectMineCard] 确认选卡失败")
		if MiningPage.isMiningPage() then
			return "miningPageScan"
		end
		return StateMachine.RETRY
	end
	
	Guard.sleep(1000)
	if not MiningPage.waitMiningPage(30000 , 500) then
		Logger.warn(TAG .. " [selectMineCard] 等待开采页超时")
		return StateMachine.RETRY
	end
	
	Logger.info(TAG .. " [selectMineCard] 已确认 → startMining")
	return "startMining"
end

local function done(sm)
	updateHud(sm , { extra = "本轮结束回城…" })
	-- 结束前复查一次，避免识别抖动导致误判全忙。
	if MiningPage.hasCompletedTask() then
		Logger.info(TAG .. " [done] 复查发现已完成任务 → confirmRewards")
		MiningPage.tapCompletedSlot()
		return "confirmRewards"
	end
	if MiningPage.hasFreeSlot() then
		Logger.info(TAG .. " [done] 复查发现空闲栏位 → selectMineCard")
		MiningPage.tapFreeSlot()
		return "selectMineCard"
	end
	if MiningPage.hasStartableCard() then
		Logger.info(TAG .. " [done] 复查发现可开采矿卡 → startMining")
		MiningPage.tapReadySlot()
		return "startMining"
	end
	
	Logger.info(TAG .. " [done] 当前页无可操作项，准备回城并记录 busy")
	updateHud(sm , { state = "idle" , extra = "本轮结束" })
	if not Route.returnToKingdom() then
		Logger.warn(TAG .. " [done] 回王国首页失败")
		return false , "矿山开采[done] 回王国首页失败"
	end
	MiningSession.enterBusyWait()
	return StateMachine.DONE
end

local handlers = {
	detect = detect ,
	navigate = navigate ,
	precheck = precheck ,
	miningPageScan = miningPageScan ,
	confirmRewards = confirmRewards ,
	startMining = startMining ,
	selectMineCard = selectMineCard ,
	done = done ,
}

function MiningTask.run()
	local cfg = UserConfig.get("mine")
	if cfg.miningEnabled ~= true then
		Logger.info(TAG .. " 任务未启用，跳过")
		return false
	end
	local cardPriority = resolveCardPriority()
	Logger.info(TAG .. " 任务启动 | miningEnabled=" .. tostring(cfg.miningEnabled)
	.. " oreCards=" .. table.concat(cardPriority , ","))
	
	StatusHud.setMineMining({
		state = "detect" ,
		extra = "任务启动" ,
	})
	
	local ctx = {
		quotaCur = nil ,
		quotaMax = nil ,
		selectedCards = nil ,
		cardSwipeDirection = "left" ,
		skipSelectOnce = nil ,
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
		label = "矿山开采" ,
	})
	if ok then
		Logger.info(TAG .. " 任务完成")
	else
		StatusHud.setMineMining({
			extra = "失败: " .. tostring(err) ,
		})
		Logger.warn(TAG .. " 任务结束：" .. tostring(err))
	end
	return ok
end

return MiningTask
