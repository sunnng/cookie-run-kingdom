--[[
模块: 王国竞技场页面
路径: game.常规_王国竞技场.竞技场_页面
--]]

local Ocr = require("lib.ocr")
local U = require("lib.utils")
local Guard = require("core.guard")
local Logger = require("lib.logger")
local DialogLib = require("lib.dialog")
local F = require("game.常规_王国竞技场.竞技场_特征库")

local ArenaPage = {}
local TAG = "[王国竞技场.页面]"

local function hasLeaveBtn()
	return cmpColorExT(F.settlement.leaveFeature) == 1
end

local function isSettlement()
	return cmpColorExT(F.settlement.feature) == 1
end

local function waitFeature(feature , maxWait , interval , label)
	maxWait = maxWait or 30000
	interval = interval or 500
	label = label or "页面"
	local deadline = tickCount() + maxWait
	while tickCount() < deadline do
		if cmpColorExT(feature) == 1 then
			Logger.debug(TAG .. " 命中 " .. label)
			return true
		end
		Guard.check()
		sleep(interval)
	end
	Logger.warn(TAG .. " 等待 " .. label .. " 超时 " .. maxWait .. "ms")
	return false
end

local function waitUntilGone(feature , maxWait , interval , label)
	maxWait = maxWait or 30000
	interval = interval or 500
	label = label or "页面"
	local deadline = tickCount() + maxWait
	while tickCount() < deadline do
		if cmpColorExT(feature) ~= 1 then
			Logger.debug(TAG .. " 已离开 " .. label)
			return true
		end
		Guard.check()
		sleep(interval)
	end
	Logger.warn(TAG .. " 离开 " .. label .. " 超时 " .. maxWait .. "ms")
	return false
end

local function retryTap(x , y , checkFn , maxRetry , checkDelay)
	maxRetry = maxRetry or 10
	checkDelay = checkDelay or 800
	for i = 1 , maxRetry do
		if checkFn() then
			return true
		end
		tap(x , y)
		Guard.sleep(checkDelay , 500)
	end
	return checkFn()
end

local function leaveSettlement()
	if ArenaPage.isLobby() then
		Logger.info(TAG .. " 已在大厅，跳过离开结算")
		return true
	end

	-- 不在结算页且不在大厅时，交给 skipPromotion 处理
	if not isSettlement() and not hasLeaveBtn() then
		Logger.info(TAG .. " 不在结算页，跳过 leaveSettlement")
		return false
	end

	local leaveRetry = F.settlement.leaveRetryTap
	local leaveTap = F.settlement.leaveTap
	local skip = F.settlement.promotionSkip

	Logger.info(TAG .. " 开始离开结算页")

	-- 1. 点击直到出现离开按钮（同时可跳过结算动画）
	if not retryTap(leaveRetry[1] , leaveRetry[2] , hasLeaveBtn , 60 , 1200) then
		Logger.warn(TAG .. " 等待离开按钮超时")
		return ArenaPage.isLobby()
	end

	-- 2. 点击离开按钮
	Logger.debug(TAG .. " 检测到离开按钮，点击离开")
	tap(leaveTap[1] , leaveTap[2])
	sleep(2000)

	-- 3. 等待回到大厅，期间持续点击跳过升段奖励
	--    处理：结算 → 大厅，或 结算 → 大厅 → 升段页 → 大厅
	if retryTap(skip[1] , skip[2] , ArenaPage.isLobby , 60 , 1000) then
		sleep(1500)
		if ArenaPage.isLobby() then
			Logger.info(TAG .. " 已回到竞技场大厅")
			return true
		end
		-- 大厅特征出现后消失（加载慢导致先回大厅再进入升段页），继续第二轮
		Logger.info(TAG .. " 大厅特征消失，继续跳过升段")
		if retryTap(skip[1] , skip[2] , ArenaPage.isLobby , 60 , 1000) then
			Logger.info(TAG .. " 已回到竞技场大厅")
			return true
		end
	end

	Logger.warn(TAG .. " 离开结算超时 lobby=" .. tostring(ArenaPage.isLobby()))
	return ArenaPage.isLobby()
end

-- 跳过升段奖励逻辑（处理已处于升段页的情况）
local function skipPromotion()
	if ArenaPage.isLobby() then
		Logger.info(TAG .. " 已在大厅，跳过升段奖励")
		return true
	end

	local skip = F.settlement.promotionSkip
	Logger.info(TAG .. " 检查升段奖励/跳过 坐标=(" .. skip[1] .. "," .. skip[2] .. ")")

	-- 第一轮：持续点击跳过坐标，直到出现大厅特征
	if retryTap(skip[1] , skip[2] , ArenaPage.isLobby , 60 , 1000) then
		sleep(1500)
		if ArenaPage.isLobby() then
			Logger.info(TAG .. " 升段流程结束，已在大厅")
			return true
		end
		-- 大厅特征出现后消失（加载慢导致先回大厅再进入升段页），继续第二轮
		Logger.info(TAG .. " 大厅特征消失，继续跳过升段")
		return retryTap(skip[1] , skip[2] , ArenaPage.isLobby , 60 , 1000)
	end

	Logger.warn(TAG .. " 升段跳过超时 lobby=" .. tostring(ArenaPage.isLobby()))
	return ArenaPage.isLobby()
end

function ArenaPage.ensureLobby()
	if ArenaPage.isLobby() then
		return true
	end
	Logger.info(TAG .. " 尝试恢复到大厅")
	if isSettlement() or hasLeaveBtn() then
		leaveSettlement()
	end
	if not ArenaPage.isLobby() then
		skipPromotion()
	end
	local ok = ArenaPage.isLobby()
	if not ok then
		Logger.warn(TAG .. " 恢复大厅失败")
	end
	return ok
end

function ArenaPage.isLobby()
	return cmpColorExT(F.lobby.feature) == 1
end

function ArenaPage.waitLobby(timeoutMs)
	return waitFeature(F.lobby.feature , timeoutMs or 30000 , 500 , "竞技场大厅")
end

function ArenaPage.tapClose(delayMs)
	delayMs = delayMs or 1200
	local btn = F.lobby.closeBtn
	tap(math.random(btn[1] , btn[3]) , math.random(btn[2] , btn[4]))
	sleep(delayMs)
end

function ArenaPage.readMedalAndTicket()
	local words = Ocr.recognizeWords(F.lobby.medalTicketOcr)
	if #words < 2 then
		Logger.warn(TAG .. " 奖牌/门票 OCR 不足 raw=" .. table.concat(words , ","))
		return nil , nil
	end
	local medal = U.parseNumber(words[1])
	local ticketInfo = U.parseStamina(words[2])
	local ticket = ticketInfo and ticketInfo.current or U.parseNumber(words[2])
	Logger.debug(string.format(
		TAG .. " OCR 奖牌=%s 门票=%s raw=[%s,%s]" ,
		tostring(medal) , tostring(ticket) , words[1] , words[2]
	))
	return medal , ticket
end

function ArenaPage.readTrophyCount()
	local raw = Ocr.recognizeText(F.lobby.trophyOcr)
	if not raw or raw == "" then
		Logger.warn(TAG .. " 奖杯 OCR 为空")
		return nil
	end
	local parsed = U.parseStamina(raw)
	local count = parsed and parsed.current or U.parseNumber(raw)
	Logger.debug(TAG .. " OCR 奖杯 raw=" .. raw .. " parsed=" .. tostring(count))
	return count
end

function ArenaPage.readOpponentInfo(location)
	local ret = findMultiColorAllT(F.opponent.findDef)
	local info = {
		site = {0 , 0} ,
		power = 0 ,
		trophies = 0 ,
		isBattled = false ,
		battleResult = "" ,
	}
	if not ret or not ret[location] then
		Logger.warn(TAG .. " 未找到对手位 " .. tostring(location))
		return info
	end

	local targetX , targetY = ret[location].x , ret[location].y
	info.site = { targetX , targetY }

	local baseX , baseY = F.opponent.baseSite[1] , F.opponent.baseSite[2]
	local ocrCfg = F.opponent.numberOcr
	local pr = F.opponent.powerRect
	local tr = F.opponent.trophyRect
	local powerRect = U.generateNewPos(targetX , targetY , baseX , baseY , pr[1] , pr[2] , pr[3] , pr[4])
	local trophyRect = U.generateNewPos(targetX , targetY , baseX , baseY , tr[1] , tr[2] , tr[3] , tr[4])

	local power = Ocr.recognizeNumber(powerRect , ocrCfg)
	if power and power ~= "" then
		info.power = U.parseNumber(power) or 0
	end
	local trophies = Ocr.recognizeNumber(trophyRect , ocrCfg)
	if trophies and trophies ~= "" then
		info.trophies = U.parseNumber(trophies) or 0
	end

	local rx = targetX + F.opponent.resultOffset[1]
	local ry = targetY + F.opponent.resultOffset[2]
	local c = F.opponent.resultColors
	if cmpColor(rx , ry , c.win , 0.95) == 1 then
		info.isBattled , info.battleResult = true , "胜利"
	elseif cmpColor(rx , ry , c.draw , 0.95) == 1 then
		info.isBattled , info.battleResult = true , "平局"
	elseif cmpColor(rx , ry , c.lose , 0.95) == 1 then
		info.isBattled , info.battleResult = true , "失败"
	end
	Logger.debug(string.format(
		TAG .. " 对手位%d 战力=%d 奖杯=%d 已战=%s 结果=%s 坐标=(%d,%d)" ,
		location , info.power , info.trophies ,
		tostring(info.isBattled) , info.battleResult ,
		info.site[1] , info.site[2]
	))
	return info
end

function ArenaPage.swipePageLeft()
	local s = F.pagination.swipeLeft
	Logger.debug(TAG .. " 左滑翻页")
	swipe(s[1] , s[2] , s[3] , s[4] , 500)
	sleep(1000)
end

function ArenaPage.swipePageRight()
	local s = F.pagination.swipeRight
	Logger.debug(TAG .. " 右滑翻页")
	swipe(s[1] , s[2] , s[3] , s[4] , 500)
	sleep(1000)
end

function ArenaPage.runBattle()
	Logger.info(TAG .. " 等待队伍选择页")
	if not waitFeature(F.teamSelect.feature , 30000 , 500 , "队伍选择") then
		return nil
	end

	local start = F.teamSelect.startBattle
	Logger.info(TAG .. " 点击开始战斗")
	tap(start[1] , start[2])

	local deployDialog = DialogLib.new(F.dialog.deployMore , { tag = TAG })
	local toppingDialog = DialogLib.new(F.dialog.missingTopping , { tag = TAG })
	local ok , summary = DialogLib.resolveUntilIdle({
		{ dialog = deployDialog , name = "deployMore" , priority = 10 ,
			opts = { action = "confirm" , waitGoneMs = 1000 , intervalMs = 500 } } ,
		{ dialog = toppingDialog , name = "missingTopping" , priority = 10 ,
			opts = { action = "confirm" , waitGoneMs = 1000 , intervalMs = 500 } } ,
	} , { timeoutMs = 8000 , minWaitMs = 500 , settleMs = 800 , maxHandled = 2 , tag = TAG })
	if not ok then
		Logger.warn(TAG .. " 战斗前弹窗处理失败 | " .. tostring(summary and summary.reason))
	end

	-- 战斗开始 UI 只短暂闪现，不能用来判断「已在战斗中」
	if not waitUntilGone(F.teamSelect.feature , 15000 , 500 , "队伍选择") then
		return nil
	end
	Logger.info(TAG .. " 已进入战斗，等待结算页")
	if not waitFeature(F.settlement.feature , 120000 , 1000 , "结算页") then
		return nil
	end

	Guard.sleep(1500 , 500)
	local result = Ocr.recognizeText(F.settlement.resultOcr)
	Logger.info(TAG .. " 战斗结果: " .. tostring(result))

	leaveSettlement()
	Logger.info(TAG .. " 战斗流程结束 lobby=" .. tostring(ArenaPage.isLobby()))
	return result
end

function ArenaPage.isFreeRefresh()
	local text = Ocr.recognizeText(F.lobby.freeRefreshOcr)
	return text == "免费刷新"
end

function ArenaPage.tapFreeRefresh()
	tap(F.lobby.freeRefreshTap[1] , F.lobby.freeRefreshTap[2])
end

--- 读取刷新倒计时并解析为秒数
--- @return number|nil 剩余秒数，解析失败返回 nil
function ArenaPage.readRefreshCountdown()
	local raw = Ocr.recognizeText(F.lobby.refreshOcr)
	if not raw or raw == "" then
		Logger.warn(TAG .. " 刷新倒计时 OCR 为空")
		return nil
	end

	local text = U.keepHanAlphaNum(raw)
	Logger.debug(TAG .. " 刷新倒计时 OCR raw=" .. raw .. " clean=" .. text)

	-- 匹配 "X分Y秒" / "X分" / "Y秒"
	local minStr , secStr = text:match("(%d+)分(%d+)秒")
	if minStr and secStr then
		return tonumber(minStr) * 60 + tonumber(secStr)
	end

	minStr = text:match("(%d+)分")
	if minStr then
		return tonumber(minStr) * 60
	end

	secStr = text:match("(%d+)秒")
	if secStr then
		return tonumber(secStr)
	end

	-- 匹配 "MM:SS" / "M:SS"
	local mm , ss = text:match("(%d+):(%d+)")
	if mm and ss then
		return tonumber(mm) * 60 + tonumber(ss)
	end

	Logger.warn(TAG .. " 无法解析刷新倒计时 text=" .. text)
	return nil
end

function ArenaPage.waitFreeRefresh()
	local maxWait = 10 * 60 * 1000
	local startTick = tickCount()
	Logger.info(TAG .. " 等待免费刷新")
	while tickCount() - startTick < maxWait do
		if ArenaPage.isFreeRefresh() then
			Logger.info(TAG .. " 点击免费刷新")
			tap(F.lobby.freeRefreshTap[1] , F.lobby.freeRefreshTap[2])
			sleep(1000)
			return true
		end
		local refreshText = U.keepHanAlphaNum(Ocr.recognizeText(F.lobby.refreshOcr))
		if refreshText == "剩余0秒" then
			Logger.info(TAG .. " 刷新倒计时归零，确认刷新")
			tap(1205 , 843)
			sleep(1500)
			tap(689 , 845)
		end
		sleep(1000)
	end
	Logger.warn(TAG .. " 等待免费刷新超时")
	return false
end

function ArenaPage.buyTicket()
	Logger.info(TAG .. " 打开买票弹窗")
	tap(F.lobby.buyTicketBtn[1] , F.lobby.buyTicketBtn[2])
	sleep(1500)
	local s = F.lobby.buyTicketSlider
	Logger.debug(TAG .. " 拖动买票滑条")
	touchDown(1 , s[1] , s[2])
	sleep(50)
	touchMoveEx(1 , s[3] , s[4] , 1000)
	touchUp(1)
	sleep(1000)
	tap(F.lobby.buyTicketConfirm[1] , F.lobby.buyTicketConfirm[2])
	Logger.info(TAG .. " 买票确认已点击")
end

return ArenaPage
