local Color = require("lib.color")
local Touch = require("lib.touch")
local Ocr = require("lib.ocr")
local Logger = require("lib.logger")
local Dialog = require("lib.dialog")

local MineFeatureLib = require("game.常规_未知的地底矿山.矿山_特征库")
local MineHomePage = require("game.常规_未知的地底矿山.矿山首页_页面")

local MiningPage = {}

local TAG = "[矿山开采.页面]"

local MiningFeatures = MineFeatureLib.mining()

local SWIPE_CARD_LIST = {
	x1 = 1480 ,
	y1 = 738 ,
	x2 = 150 ,
	y2 = 738 ,
	moveMs = 600 ,
	holdMs = 1000 ,
	downMs = 50 ,
}

local DEDUP_RADIUS = 80
local SELECTED_NEAR_RADIUS = 120
local MAX_SWIPES = 20
local TAP_Y_OFFSET = - 200
local TAP_SETTLE_MS = 450

local function hasFeature(feature)
	return type(feature) == "table" and feature[1] ~= nil
end

local function reverseSwipe(opts)
	return {
		x1 = opts.x2 ,
		y1 = opts.y2 ,
		x2 = opts.x1 ,
		y2 = opts.y1 ,
		moveMs = opts.moveMs ,
		holdMs = opts.holdMs ,
		downMs = opts.downMs ,
		steps = opts.steps ,
		id = opts.id ,
	}
end

local function sortByX(points)
	table.sort(points , function(a , b)
		return a.x < b.x
	end)
	return points
end

local function isNearExisting(pt , list , radius)
	radius = radius or DEDUP_RADIUS
	local r2 = radius * radius
	for _ , p in ipairs(list) do
		local dx = pt.x - p.x
		local dy = pt.y - p.y
		if dx * dx + dy * dy <= r2 then
			return true
		end
	end
	return false
end

local function findSelectedCardPoints()
	local mark = MiningFeatures.cardSelect and MiningFeatures.cardSelect.selectedMark
	if not hasFeature(mark) then
		return {}
	end
	return Color.findAll(mark)
end

local function tapCardPoint(pt)
	Touch.tapR(pt.x , pt.y + TAP_Y_OFFSET , TAP_SETTLE_MS)
end

local function tapCardIfQuotaIncreases(pt , targetCur)
	local before = MiningPage.readChooseQuota()
	if not before or before >= targetCur then
		return false
	end
	tapCardPoint(pt)
	local after = MiningPage.readChooseQuota()
	if not after then
		return false
	end
	if after > before then
		Logger.debug(string.format(TAG .. " 选中 +1 (%d→%d)" , before , after))
		return true
	end
	if after < before then
		Logger.warn(string.format(TAG .. " 误触已选卡 (%d→%d)，恢复" , before , after))
		tapCardPoint(pt)
	end
	return false
end

local function ocrRectHasText(rect)
	local r = Ocr.scan(rect)
	if not r then
		return false
	end
	if (r.text or ""):match("%S") then
		return true
	end
	for _ , item in ipairs(r.items or {}) do
		if (item.words or ""):match("%S") then
			return true
		end
	end
	return false
end

local function swipeCardList(direction)
	direction = direction or "left"
	local opts = direction == "right" and reverseSwipe(SWIPE_CARD_LIST) or SWIPE_CARD_LIST
	local id = opts.id or 1
	local moveMs = math.max(1 , math.floor(opts.moveMs or 600))
	local holdMs = math.max(0 , math.floor(opts.holdMs or 200))
	local downMs = math.max(0 , math.floor(opts.downMs or 50))
	local steps = math.max(1 , math.floor(opts.steps or 1))
	
	touchDown(id , math.floor(opts.x1) , math.floor(opts.y1))
	if downMs > 0 then
		sleep(downMs)
	end
	
	local segMs = math.max(1 , math.floor(moveMs / steps))
	for i = 1 , steps do
		local t = i / steps
		local x = opts.x1 + (opts.x2 - opts.x1) * t
		local y = opts.y1 + (opts.y2 - opts.y1) * t
		touchMoveEx(id , math.floor(x) , math.floor(y) , segMs)
	end
	
	if holdMs > 0 then
		sleep(holdMs)
	end
	
	local edgeRect = direction == "right"
		and (MiningFeatures.cardListStartOcr or { 95 , 452 , 390 , 532 })
		or (MiningFeatures.cardListEndOcr or { 1210 , 452 , 1505 , 532 })
	local canContinue = ocrRectHasText(edgeRect)
	touchUp(id)
	if not canContinue then
		Logger.info(TAG .. " 卡列表" .. (direction == "right" and "左缘" or "右缘") .. "无文字，已到尽头")
		return false
	end
	sleep(500)
	return true
end

function MiningPage.isMiningPage()
	return hasFeature(MiningFeatures.page.feature) and Color.match(MiningFeatures.page.feature)
end

function MiningPage.waitMiningPage(timeoutMs , intervalMs)
	if not hasFeature(MiningFeatures.page.feature) then
		return false
	end
	return Color.wait(MiningFeatures.page.feature , timeoutMs or 60000 , intervalMs or 500)
end

function MiningPage.isSetup()
	return hasFeature(MiningFeatures.setupFeature) and Color.match(MiningFeatures.setupFeature)
end

function MiningPage.isSetupReady()
	return hasFeature(MiningFeatures.setupReadyFeature) and Color.match(MiningFeatures.setupReadyFeature)
end

function MiningPage.waitSetupReady(timeoutMs , intervalMs)
	if not hasFeature(MiningFeatures.setupReadyFeature) then
		Logger.warn(TAG .. " setupReadyFeature 未配置")
		return false
	end
	return Color.wait(MiningFeatures.setupReadyFeature , timeoutMs or 30000 , intervalMs or 500)
end

function MiningPage.isRewardPage()
	local reward = MiningFeatures.rewardPage
	if reward.titleText and reward.titleOcr and Ocr.has(reward.titleText , reward.titleOcr) then
		return true
	end
	return hasFeature(reward.feature) and Color.match(reward.feature)
end

function MiningPage.isSettlementRoute()
	return not MineHomePage.isCurrent() and not MiningPage.isMiningPage()
end

function MiningPage.tapUntilMatchMiningPage()
	if not MiningFeatures.rewardPage.confirmBtn or not hasFeature(MiningFeatures.page.feature) then
		Logger.warn(TAG .. " rewardPage.confirmBtn / page.feature 未配置")
		return false
	end
	return Color.tapUntilMatch(
		MiningFeatures.rewardPage.confirmBtn ,
		MiningFeatures.page.feature ,
		{ timeoutMs = 30000 , intervalMs = 500 })
end

function MiningPage.hasCompletedTask()
	local completed = MiningFeatures.completedTask
	return hasFeature(completed.feature) and Color.find(completed.feature) ~= nil
end

function MiningPage.tapCompletedSlot()
	local completed = MiningFeatures.completedTask
	if not hasFeature(completed.feature) then
		Logger.warn(TAG .. " completedTask 特征未配置")
		return false
	end
	local x , y = Color.find(completed.feature)
	if not x then
		return false
	end
	Touch.tapR(x , y , 500)
	return true
end

function MiningPage.hasFreeSlot()
	if hasFeature(MiningFeatures.freeLocationFeature) and Color.find(MiningFeatures.freeLocationFeature) ~= nil then
		return true
	end
	return hasFeature(MiningFeatures.freePlusFeature) and Color.find(MiningFeatures.freePlusFeature) ~= nil
end

function MiningPage.enterMultiSelect()
	if not MiningFeatures.multiSelectBtn then
		Logger.warn(TAG .. " multiSelectBtn 未配置")
		return false
	end
	local ocrRect = MiningFeatures.multiSelectOcr or MiningFeatures.multiSelectBtn
	if not Ocr.wait("选择多个" , ocrRect , 30000 , 500) then
		return false
	end
	Touch.tapArea(MiningFeatures.multiSelectBtn , 1000)
	return true
end

function MiningPage.tapFreeSlot()
	if not hasFeature(MiningFeatures.freeLocationFeature) then
		Logger.warn(TAG .. " freeLocationFeature 未配置")
		return false
	end
	local x , y = Color.find(MiningFeatures.freeLocationFeature)
	if not x and hasFeature(MiningFeatures.freePlusFeature) then
		x , y = Color.find(MiningFeatures.freePlusFeature)
	end
	if not x or not y then
		return false
	end
	Touch.tapR(x , y , 500)
	return MiningPage.enterMultiSelect()
end

function MiningPage.readChooseQuota()
	return Ocr.fraction(MiningFeatures.canChooseNum)
end

function MiningPage.selectTargetCards(targetDef , needCount , direction)
	if needCount <= 0 then
		return 0 , false
	end
	if not hasFeature(targetDef) then
		Logger.warn(TAG .. " 目标矿卡特征未配置")
		return 0 , true
	end
	
	local startCur , startMax = MiningPage.readChooseQuota()
	startCur = startCur or 0
	startMax = startMax or needCount
	local targetCur = startCur + needCount
	direction = direction or "left"
	
	local swipes = 0
	local exhausted = false
	while swipes <= MAX_SWIPES do
		local cur , max = MiningPage.readChooseQuota()
		cur = cur or startCur
		max = max or startMax
		if cur >= max or cur >= targetCur then
			return cur - startCur , false
		end
		
		local selectedMarks = findSelectedCardPoints()
		local tappedThisPass = {}
		local progressed = false
		local points = sortByX(Color.findAll(targetDef))
		Logger.info(string.format(
			TAG .. " 扫描目标卡 方向:%s 可见:%d 已选:%d 还需:%d 滑动:%d" ,
			direction , #points , cur - startCur , targetCur - cur , swipes
		))
		
		for _ , pt in ipairs(points) do
			cur = MiningPage.readChooseQuota()
			if not cur or cur >= targetCur then
				break
			end
			if isNearExisting(pt , tappedThisPass) then
				-- 同屏重复命中同一张卡，跳过。
			elseif isNearExisting(pt , selectedMarks , SELECTED_NEAR_RADIUS) then
				Logger.debug(TAG .. " 跳过已选标记卡")
			else
				tappedThisPass[#tappedThisPass + 1] = pt
				if tapCardIfQuotaIncreases(pt , targetCur) then
					progressed = true
				end
			end
		end
		
		cur = MiningPage.readChooseQuota()
		if cur and cur >= targetCur then
			return cur - startCur , false
		end
		
		if not progressed then
			if not swipeCardList(direction) then
				exhausted = true
				break
			end
			swipes = swipes + 1
		end
	end
	
	if swipes > MAX_SWIPES then
		exhausted = true
	end
	local finalCur = MiningPage.readChooseQuota() or startCur
	Logger.warn(string.format(TAG .. " 选卡不足 %d/%d（滑动%d次）" , finalCur - startCur , needCount , swipes))
	return finalCur - startCur , exhausted
end

function MiningPage.confirmCardSelection()
	local btn = MiningFeatures.cardSelect.confirmBtn
	if not btn then
		Logger.warn(TAG .. " cardSelect.confirmBtn 未配置")
		return false
	end
	Touch.tapArea(btn , 800)
	return true
end

function MiningPage.hasStartableCard()
	local startable = MiningFeatures.startableCard
	return hasFeature(startable.feature) and Color.find(startable.feature) ~= nil
end

function MiningPage.tapReadySlot()
	local startable = MiningFeatures.startableCard
	if not hasFeature(startable.feature) then
		Logger.warn(TAG .. " startableCard 特征未配置")
		return false
	end
	local x , y = Color.find(startable.feature)
	if not x then
		return false
	end
	Touch.tapR(x - 100 , y + 100 , 500)
	if not hasFeature(MiningFeatures.setupFeature) then
		Logger.warn(TAG .. " setupFeature 未配置")
		return false
	end
	return Color.wait(MiningFeatures.setupFeature , 30000 , 500)
end

function MiningPage.autoSelectCookieAndStart()
	local autoBtn = MiningFeatures.autoSelectCookieBtn
	local startBtn = MiningFeatures.confirmStartBtn
	if not autoBtn or not startBtn then
		Logger.warn(TAG .. " autoSelectCookieBtn / confirmStartBtn 未配置")
		return false
	end
	
	Touch.tapArea(autoBtn , 500)
	if not MiningPage.waitSetupReady() then
		return false
	end
	Touch.tapArea(startBtn , 500)

	local cookieDialog = Dialog.new(MiningFeatures.dialogConfirmCookie , { tag = TAG })
	local countWarningDialog = Dialog.new(MiningFeatures.dialogCookieCountWarning , { tag = TAG })

	-- 两个弹窗出现顺序未知，使用 resolveUntilIdle 处理
	local ok , summary = Dialog.resolveUntilIdle({
		{ dialog = cookieDialog , name = "confirmCookie" , priority = 10 ,
		  opts = { action = "confirm" , neverAgain = true , waitGoneMs = 2000 , intervalMs = 300 } } ,
		{ dialog = countWarningDialog , name = "cookieCountWarning" , priority = 10 ,
		  opts = { action = "confirm" , neverAgain = true , waitGoneMs = 2000 , intervalMs = 300 } } ,
	} , { timeoutMs = 8000 , minWaitMs = 500 , settleMs = 800 , maxHandled = 2 , tag = TAG })

	if not ok then
		Logger.warn(TAG .. " 饼干弹窗处理失败 | " .. tostring(summary and summary.reason))
		return false
	end
	return true
end

function MiningPage.tapBackBtn()
	Touch.tapArea(MiningFeatures.backBtn , 1000)
end

return MiningPage
