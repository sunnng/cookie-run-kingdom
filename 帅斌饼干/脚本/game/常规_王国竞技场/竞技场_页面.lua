--[[
模块: 王国竞技场页面
路径: game.常规_王国竞技场.竞技场_页面
--]]

local Ocr = require("lib.ocr")
local U = require("lib.utils")
local Guard = require("core.guard")
local Logger = require("lib.logger")
local Touch = require("lib.touch")
local Color = require("lib.color")
local F = require("game.常规_王国竞技场.竞技场_特征库")

local ArenaPage = {}
local TAG = "[王国竞技场.页面]"

local function hasLeaveBtn()
	return Color.match(F.settlement.leaveFeature)
end

local function isSettlement()
	return Color.match(F.settlement.feature)
end

local function waitFeature(feature , maxWait , interval , label)
	maxWait = maxWait or 30000
	interval = interval or 500
	label = label or "页面"
	local ok = Color.wait(feature , maxWait , interval)
	if ok then
		Logger.debug(TAG .. " 命中 " .. label)
	else
		Logger.warn(TAG .. " 等待 " .. label .. " 超时 " .. maxWait .. "ms")
	end
	return ok
end

local function leaveSettlement()
	-- 防御性编程
	if ArenaPage.isLobby() then
		return true
	end
	
	if not isSettlement() and not hasLeaveBtn() then
		return false
	end
	
	-- 连续点击离开按钮区域
	if Color.tapUntilMatch(F.settlement.leaveBtn , F.lobby.feature , {timeoutMs = 60000 , intervalMs = 500 , tapDelayMs = 500 , sleepMs = 1200}) then
		-- 防止先到达大厅,再弹出升段页面
		if ArenaPage.isLobby() then
			return true
		else
			-- 再次执行
			if Color.tapUntilMatch(F.settlement.leaveBtn , F.lobby.feature , {timeoutMs = 60000 , intervalMs = 500 , tapDelayMs = 500 , sleepMs = 1200}) then
				return true
			else
				return false
			end
		end
		
	end
	
	return false
end

function ArenaPage.isLobby()
	return Color.match(F.lobby.feature)
end

function ArenaPage.waitLobby(timeoutMs)
	return waitFeature(F.lobby.feature , timeoutMs or 30000 , 500 , "竞技场大厅")
end

function ArenaPage.tapClose(delayMs)
	Touch.tapArea(F.lobby.closeBtn , delayMs or 1200)
end

function ArenaPage.readMedalAndTicket()
	local words = Ocr.recognizeWords(F.lobby.medalTicketOcr)
	if #words < 2 then
		return nil , nil
	end
	local medal = U.parseNumber(words[1])
	local ticketInfo = U.parseStamina(words[2])
	local ticket = ticketInfo and ticketInfo.current or U.parseNumber(words[2])
	return medal , ticket
end

function ArenaPage.readTrophyCount()
	local raw = Ocr.recognizeText(F.lobby.trophyOcr)
	if not raw or raw == "" then
		return nil
	end
	local parsed = U.parseStamina(raw)
	return parsed and parsed.current or U.parseNumber(raw)
end

function ArenaPage.readOpponentInfo(location)
	local ret = findMultiColorAllT(F.opponent.findDef)
	local info = {
		site = {0 , 0} ,
		isBattled = false ,
		battleResult = "" ,
	}
	if not ret or not ret[location] then
		return info
	end
	
	local targetX , targetY = ret[location].x , ret[location].y
	info.site = { targetX , targetY }
	
	local baseX , baseY = F.opponent.baseSite[1] , F.opponent.baseSite[2]
	local ocrCfg = F.opponent.numberOcr
	local tr = F.opponent.trophyRect
	local trophyRect = U.generateNewPos(targetX , targetY , baseX , baseY , tr[1] , tr[2] , tr[3] , tr[4])
	
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
	return info
end

local function isClose(a , b , threshold)
	if a == nil or b == nil or threshold == nil then
		return false
	end
	return math.abs(a - b) < threshold
end

--- 扫描当前页所有对手，返回第一个符合要求的对手信息
--- @param cfg table 用户配置（含 trophyDiff）
--- @param myTrophy number 我方当前奖杯数
--- @return table|nil 对手信息，无合适对手返回 nil
function ArenaPage.findFirstValidOpponent(cfg , myTrophy)
	local ret = findMultiColorAllT(F.opponent.findDef)
	if not ret or #ret == 0 then
		return nil
	end
	
	local trophyDiff = cfg and cfg.trophyDiff or 0
	for loc = 1 , #ret do
		local info = ArenaPage.readOpponentInfo(loc)
		if info.site[1] ~= 0 and info.site[2] ~= 0 then
			if info.isBattled then
				Logger.info(string.format(
				TAG .. " 位%d 已战斗(%s) 跳过" ,
				loc , info.battleResult
				))
			elseif myTrophy > info.trophies and not isClose(myTrophy , info.trophies , trophyDiff) then
				Logger.info(string.format(
				TAG .. " 位%d 奖杯过滤 我方=%d 对手=%d" ,
				loc , myTrophy , info.trophies
				))
			else
				Logger.info(string.format(
				TAG .. " 位%d 可开战  奖杯=%d" ,
				loc , info.trophies
				))
				return info
			end
		end
	end
	return nil
end

function ArenaPage.swipePageLeft()
	local s = F.pagination.swipeLeft
	Logger.debug(TAG .. " 左滑翻页")
	Touch.swipeX(s[1] , s[3] , s[2] , { moveMs = 500 , holdMs = 200 })
	Guard.sleep(1000 , 500)
end

function ArenaPage.runBattle()
	Logger.info(TAG .. " 等待队伍选择页")
	if not waitFeature(F.teamSelect.feature , 30000 , 500 , "队伍选择") then
		return nil
	end
	
	local start = F.teamSelect.startBattle
	Logger.info(TAG .. " 点击开始战斗")
	Touch.tapR(start[1] , start[2] , 1000)
	
	-- 处理弹窗
	if Color.match(F.dialog.deployMore.feature) then
		Touch.tapR(F.dialog.deployMore.confirm[1] , F.dialog.deployMore.confirm[2] , 1000)
	end
	if Color.match(F.dialog.missingTopping.feature) then
		Touch.tapR(F.dialog.missingTopping.confirm[1] , F.dialog.missingTopping.confirm[2] , 0)
	end
	
	-- 等待队伍选择页消失，作为进入战斗的标志
	Logger.info(TAG .. " 等待队伍选择页消失")
	if not Color.waitGone(F.teamSelect.feature , 30000 , 500) then
		Logger.warn(TAG .. " 队伍选择页未消失，可能未进入战斗")
		return nil
	end
	
	Logger.info(TAG .. " 已进入战斗，等待结算页")
	if not waitFeature(F.settlement.feature , 120000 , 1000 , "结算页") then
		Logger.warn(TAG .. " 未等到结算页")
		return nil
	end
	
	Guard.sleep(1500 , 500)
	local result = Ocr.recognizeText(F.settlement.resultOcr)
	Logger.info(TAG .. " 战斗结果: " .. tostring(result))
	
	if not leaveSettlement() and not ArenaPage.isLobby() then
		Logger.warn(TAG .. " 离开结算失败")
		return nil
	end
	return result
end

function ArenaPage.isFreeRefresh()
	local text = Ocr.recognizeText(F.lobby.freeRefreshOcr)
	return text == "免费刷新"
end

function ArenaPage.tapFreeRefresh()
	Touch.tapR(F.lobby.freeRefreshTap[1] , F.lobby.freeRefreshTap[2] , 1000)
end

function ArenaPage.readRefreshCountdown()
	local raw = Ocr.recognizeText(F.lobby.refreshOcr)
	if not raw or raw == "" then
		return nil
	end
	
	local text = U.keepHanAlphaNum(raw)
	Logger.debug(TAG .. " 刷新倒计时原始OCR=[" .. tostring(raw) .. "] 过滤后=[" .. text .. "]")
	
	-- 先提取所有数字，再按"分/秒"关键字组合（兼容 OCR 中间夹杂乱码）
	local numbers = {}
	for num in text:gmatch("%d+") do
		numbers[#numbers + 1] = tonumber(num)
	end
	
	local hasMin = text:find("分") ~= nil
	local hasSec = text:find("秒") ~= nil
	
	if #numbers == 0 then
		Logger.warn(TAG .. " 未能解析倒计时: " .. text)
		return nil
	end
	
	-- 同时出现"分"和"秒"：取前两个数字分别作为分、秒
	if hasMin and hasSec then
		if #numbers >= 2 then
			return numbers[1] * 60 + numbers[2]
		else
			Logger.warn(TAG .. " 有分秒关键字但只有一个数字: " .. text)
			return numbers[1] * 60
		end
	end
	
	-- 只有"秒"
	if hasSec then
		return numbers[1]
	end
	
	-- 只有"分"
	if hasMin then
		Logger.warn(TAG .. " 只解析到分钟，秒数缺失: " .. text)
		return numbers[1] * 60
	end
	
	-- 兜底：冒号格式 mm:ss
	local mm , ss = text:match("(%d+):(%d+)")
	if mm and ss then
		return tonumber(mm) * 60 + tonumber(ss)
	end
	
	Logger.warn(TAG .. " 未能解析倒计时: " .. text)
	return nil
end

function ArenaPage.buyTicket()
	Logger.info(TAG .. " 打开买票弹窗")
	Touch.tapR(F.lobby.buyTicketBtn[1] , F.lobby.buyTicketBtn[2] , 1500)
	local s = F.lobby.buyTicketSlider
	Logger.debug(TAG .. " 拖动买票滑条")
	Touch.swipeEx({
		x1 = s[1] , y1 = s[2] , x2 = s[3] , y2 = s[4] ,
		moveMs = 1000 , holdMs = 200 , downMs = 50 ,
	})
	Guard.sleep(1000 , 500)
	Touch.tapR(F.lobby.buyTicketConfirm[1] , F.lobby.buyTicketConfirm[2] , 0)
	Logger.info(TAG .. " 买票确认已点击")
end

return ArenaPage
