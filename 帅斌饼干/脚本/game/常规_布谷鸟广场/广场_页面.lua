local Color = require("lib.color")
local Touch = require("lib.touch")
local Ocr = require("lib.ocr")
local Logger = require("lib.logger")
local SquareFeatureLib = require("game.常规_布谷鸟广场.广场_特征库")

local SquarePage = {}
local TAG = "[布谷鸟广场]"
local Dialog = SquareFeatureLib.dialogLeave

--- @param rect table|nil
--- @param label string|nil
--- @return number|nil
local function readCount(rect , label)
	if not rect then
		Logger.warn(TAG .. " OCR 区域未配置: " .. tostring(label))
		return nil
	end
	local n = Ocr.number(rect)
	if n ~= nil then
		return n
	end
	local text = Ocr.text(rect , "text")
	if text and text ~= "" then
		local digits = text:gsub("%D" , "")
		if digits ~= "" then
			return tonumber(digits)
		end
		Logger.warn(TAG .. string.format(" %s OCR 有字无数: %s" , tostring(label) , text))
	end
	return nil
end

--- @param text string|nil
--- @return boolean
local function textIndicatesMaxed(text)
	if not text or text == "" then
		return false
	end
	if text:find("最大" , 1 , true) then
		return true
	end
	if text:find("已领取" , 1 , true) and text:find("奖励" , 1 , true) then
		return true
	end
	return false
end

function SquarePage.isCurrent()
	return Color.match(SquareFeatureLib.home.feature)
end

function SquarePage.waitHome(timeoutMs , intervalMs , sleepMs)
	return Color.waitMatch(SquareFeatureLib.home.feature , timeoutMs or 30000 , intervalMs or 500 , sleepMs or 1000)
end

function SquarePage.isLeaveDialog()
	return Color.match(Dialog.feature)
end

function SquarePage.waitLeaveDialog(timeoutMs , intervalMs , sleepMs)
	return Color.waitMatch(Dialog.feature , timeoutMs or 15000 , intervalMs or 500 , sleepMs)
end

function SquarePage.tapBackBtn()
	Touch.tapArea(SquareFeatureLib.home.backBtn)
end

function SquarePage.tapBack(delayMs)
	Touch.tapArea(SquareFeatureLib.home.backBtn , delayMs or 1000)
end

function SquarePage.tapLeaveBtn(delayMs)
	Touch.tapArea(Dialog.leaveBtn , delayMs or 1200)
end

function SquarePage.tapReturnKingdom(delayMs)
	Touch.tapArea(Dialog.leaveBtn , delayMs or 1200)
end

function SquarePage.tapCancelBtn(delayMs)
	Touch.tapArea(Dialog.cancelBtn , delayMs or 1200)
end

function SquarePage.tapCloseDialog(delayMs)
	Touch.tapArea(Dialog.cancelBtn , delayMs or 1200)
end

function SquarePage.tapConfirmRewardBtn(delayMs)
	Touch.tapArea(Dialog.confirmRewardBtn , delayMs or 1000)
end

function SquarePage.tapClaimAll(delayMs)
	Touch.tapArea(Dialog.confirmRewardBtn , delayMs or 1000)
end

function SquarePage.tapUtilDialog()
	Color.tapUntilMatch({722 , 686 , 886 , 725} , Dialog.feature)
end

function SquarePage.tapConfirmReward(delayMs)
	Touch.tapArea(Dialog.confirmRewardBtn , delayMs or 1000)
end

function SquarePage.getRewardNow()
	return readCount(Dialog.rewardNowOcr , "目前可获得奖励")
end

function SquarePage.getRewardTotal()
	return readCount(Dialog.rewardTotalOcr , "累计获得奖励")
end

function SquarePage.isDailyRewardsMaxed()
	if not SquarePage.isLeaveDialog() then
		return false
	end
	local rect = Dialog.isFinishOcr or Dialog.dailyMaxOcr
	if Ocr.has("最大" , rect) then
		Logger.info(TAG .. " 满额标识 OCR: 最大")
		return true
	end
	local scan = Ocr.scan(rect , 2 , "json")
	if scan then
		if scan.raw and textIndicatesMaxed(scan.raw) then
			return true
		end
		if scan.text and textIndicatesMaxed(scan.text) then
			return true
		end
	end
	return false
end

function SquarePage.isFinishOcr()
	return SquarePage.isDailyRewardsMaxed()
end

--- @return number|nil pending, number|nil total, number|nil sum
function SquarePage.readRewardSum()
	if not SquarePage.isLeaveDialog() then
		Logger.warn(TAG .. " 不在离开广场弹窗，无法 OCR")
		return nil , nil , nil
	end
	local pending = SquarePage.getRewardNow()
	local total = SquarePage.getRewardTotal()
	if pending == nil or total == nil then
		Logger.warn(TAG .. string.format(
		" 奖励 OCR 失败 目前=%s 累计=%s" ,
		tostring(pending) , tostring(total)
		))
		return pending , total , nil
	end
	local sum = pending + total
	Logger.info(TAG .. string.format(" 奖励 可获得=%d 累计=%d 总计=%d" , pending , total , sum))
	return pending , total , sum
end

function SquarePage.readJelliesSum()
	return SquarePage.readRewardSum()
end

return SquarePage
