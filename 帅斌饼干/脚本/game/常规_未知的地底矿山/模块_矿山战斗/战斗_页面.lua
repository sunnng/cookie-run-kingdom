--[[
模块: 矿山战斗页面
路径: game.常规_未知的地底矿山.模块_矿山战斗.战斗_页面
功能: 矿山战斗页图色识别、OCR、触控封装
依赖: lib.color, lib.touch, lib.ocr, lib.logger, game.常规_未知的地底矿山.矿山_特征库
--]]

local Color = require("lib.color")
local Touch = require("lib.touch")
local Ocr = require("lib.ocr")
local Logger = require("lib.logger")

local MineFeatureLib = require("game.常规_未知的地底矿山.矿山_特征库")

local BattlePage = {}

local TAG = "[矿山战斗.页面]"

local BattleFeatures = MineFeatureLib.battle()

local SOUL_STONE_CATEGORIES = { "史诗" , "传奇" , "上古" , "野兽" }

--- @return boolean
local function hasFeature(feature)
	return type(feature) == "table" and feature[1] ~= nil
end

--- 判断当前是否在矿山战斗页
--- @return boolean
function BattlePage.isBattlePage()
	return hasFeature(BattleFeatures.feature) and Color.match(BattleFeatures.feature)
end

--- 等待矿山战斗页出现
--- @param timeoutMs number|nil
--- @param intervalMs number|nil
--- @return boolean
function BattlePage.waitBattlePage(timeoutMs , intervalMs)
	if not hasFeature(BattleFeatures.feature) then
		return false
	end
	return Color.waitMatch(BattleFeatures.feature , timeoutMs or 30000 , intervalMs or 500 , 1000)
end

--- 点击战斗页返回按钮
function BattlePage.tapBackBtn()
	Touch.tapArea(BattleFeatures.backBtn , 1000)
end

--- 查找快转按钮
--- @return number|nil x
--- @return number|nil y
function BattlePage.findQuickBattleButton()
	if not hasFeature(BattleFeatures.快转_按钮) then
		return nil , nil
	end
	return Color.find(BattleFeatures.快转_按钮)
end

--- 点击指定坐标的快转按钮
--- @param x number
--- @param y number
function BattlePage.tapQuickBattleButton(x , y)
	Touch.tapR(x , y , 1000)
end

--- 等待快转弹窗出现
--- @param timeoutMs number|nil
--- @param intervalMs number|nil
--- @return boolean
function BattlePage.waitQuickBattleDialog(timeoutMs , intervalMs)
	if not hasFeature(BattleFeatures.快转_弹窗.feature) then
		return false
	end
	return Color.waitMatch(BattleFeatures.快转_弹窗.feature , timeoutMs or 10000 , intervalMs or 500 , 500)
end

--- 等待快转弹窗消失
--- @param timeoutMs number|nil
--- @param intervalMs number|nil
--- @return boolean
function BattlePage.waitQuickBattleDialogGone(timeoutMs , intervalMs)
	if not hasFeature(BattleFeatures.快转_弹窗.feature) then
		return true
	end
	return Color.waitGone(BattleFeatures.快转_弹窗.feature , timeoutMs or 10000 , intervalMs or 500)
end

--- 读取快转发条数量（使用/持有）
--- @return number|nil used
--- @return number|nil owned
--- @return string|nil raw
function BattlePage.readClockCount()
	local rect = BattleFeatures.快转_弹窗.快转发条数量_Ocr
	if not rect then
		Logger.warn(TAG .. " 快转发条数量_Ocr 未配置")
		return nil , nil , nil
	end

	-- 先用单行 OCR 取原始文本再手动解析，避免 fraction 兜底逻辑误识别
	local text = Ocr.text(rect , "text")
	if text and text ~= "" then
		local clean = text:gsub("%s+", ""):gsub(",", ""):gsub("，", "")
		local used , owned = clean:match("(%d+)/(%d+)")
		if used and owned then
			return tonumber(used) , tonumber(owned) , text
		end
		Logger.debug(TAG .. " 发条数量手动解析失败: " .. text)
		-- 原始文本存在但无法解析成分数，直接返回 nil，避免 fraction 二次 OCR 误识别
		return nil , nil , text
	end

	return nil , nil , nil
end

--- 点击快转弹窗确认按钮
function BattlePage.tapQuickBattleConfirm()
	Touch.tapArea(BattleFeatures.快转_弹窗.confirmBtn , 1000)
end

--- 点击快转弹窗取消按钮
function BattlePage.tapQuickBattleCancel()
	Touch.tapArea(BattleFeatures.快转_弹窗.cancelBtn , 1000)
end

--- 点击结算按钮，直到矿山战斗页再次出现
--- @return boolean
function BattlePage.tapSettleUntilBattlePage()
	if not BattleFeatures.settleBtn then
		Logger.warn(TAG .. " settleBtn 未配置")
		return false
	end
	if not hasFeature(BattleFeatures.feature) then
		Logger.warn(TAG .. " battle feature 未配置")
		return false
	end
	return Color.tapUntilMatch(
		BattleFeatures.settleBtn ,
		BattleFeatures.feature ,
		{ timeoutMs = 30000 , intervalMs = 500 , tapDelayMs = 800 , sleepMs = 800 }
	)
end

--- 查找本页所有战斗卡
--- @return table[] points
function BattlePage.findBattleCards()
	if not hasFeature(BattleFeatures.战斗卡_特征) then
		Logger.warn(TAG .. " 战斗卡_特征 未配置")
		return {}
	end
	return Color.findAll(BattleFeatures.战斗卡_特征)
end

--- 点击战斗卡
--- @param point table {x, y}
function BattlePage.tapBattleCard(point)
	Touch.tapR(point.x , point.y , 1000)
end

--- 识别灵魂石类型，返回匹配到的具体名称
--- 同一区域若命中多个目标灵魂石，视为无法区分，返回 nil 避免误判
--- @param targetNames table<string, boolean> 用户勾选的灵魂石名称集合
--- @return string|nil name 匹配到的灵魂石名称
function BattlePage.recognizeSoulStoneType(targetNames)
	if not targetNames or next(targetNames) == nil then
		return nil
	end

	local matches = {}
	for _ , category in ipairs(SOUL_STONE_CATEGORIES) do
		local defs = BattleFeatures.灵魂石类型[category]
		if type(defs) == "table" then
			for name , def in pairs(defs) do
				if targetNames[name] and hasFeature(def) then
					local x , y = Color.find(def)
					if x then
						matches[#matches + 1] = { name = name , category = category , x = x , y = y }
					end
				end
			end
		end
	end

	if #matches == 0 then
		return nil
	end

	if #matches == 1 then
		local m = matches[1]
		Logger.debug(string.format(TAG .. " 灵魂石匹配 %s/%s" , m.category , m.name))
		return m.name
	end

	-- 多个目标灵魂石同时命中，输出候选列表供排查
	local parts = {}
	for _ , m in ipairs(matches) do
		parts[#parts + 1] = string.format("%s/%s(%d,%d)" , m.category , m.name , m.x , m.y)
	end
	Logger.warn(TAG .. " 灵魂石多个候选命中，无法区分: " .. table.concat(parts , " , "))
	return nil
end

--- 向上滑动并识别是否已到末页
--- 滑动过程中保持按住，识别完成后再松手
--- @return boolean isLastPage 是否已到末页
function BattlePage.swipeUpAndCheckLastPage()
	local swipe = BattleFeatures.翻页滑动
	if not swipe or not swipe.x1 or not swipe.y1 or not swipe.x2 or not swipe.y2 then
		Logger.warn(TAG .. " 翻页滑动 未配置")
		return true
	end

	if not hasFeature(BattleFeatures.末页_特征) then
		Logger.warn(TAG .. " 末页_特征 未配置")
		return true
	end

	local id = 1
	local x1 , y1 = math.floor(swipe.x1) , math.floor(swipe.y1)
	local x2 , y2 = math.floor(swipe.x2) , math.floor(swipe.y2)

	touchDown(id , x1 , y1)
	sleep(50)
	touchMoveEx(id , x2 , y2 , 500)
	sleep(200)

	local isLastPage = Color.find(BattleFeatures.末页_特征) ~= nil

	touchUp(id)
	sleep(500)

	Logger.info(TAG .. " 翻页 hold 识别末页=" .. tostring(isLastPage))
	return isLastPage
end

return BattlePage
