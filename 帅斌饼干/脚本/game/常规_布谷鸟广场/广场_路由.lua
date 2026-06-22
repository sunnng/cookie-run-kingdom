local Color = require("lib.color")
local Touch = require("lib.touch")
local Logger = require("lib.logger")
local KingdomFeatureLib = require("game.通用_王国.特征库")
local KingdomPage = require("game.通用_王国.页面")
local SquarePage = require("game.常规_布谷鸟广场.广场_页面")

local SquareRoute = {}
local TAG = "[布谷鸟广场路由]"
local kingdomHomeFeatures = KingdomFeatureLib.home()

local function waitKingdom(timeoutMs)
	return Color.waitMatch(KingdomPage.HOME_FEATURE , timeoutMs or 30000 , 500 , 2000)
end

function SquareRoute.kingdomToSquare()
	if SquarePage.isCurrent() then
		return true
	end
	if not KingdomPage.isKingdomHome() then
		Logger.warn(TAG .. " 不在王国主城，无法进广场")
		return false
	end
	Touch.tapArea(kingdomHomeFeatures.squareBtn)
	if SquarePage.waitHome() then
		Logger.info(TAG .. " 已进入广场")
		return true
	end
	Logger.warn(TAG .. " 进入广场超时")
	return false
end

--- 打开「离开广场」弹窗
--- @return boolean
function SquareRoute.openLeaveDialog()
	if SquarePage.isLeaveDialog() then
		return true
	end
	if not SquarePage.isCurrent() then
		if not SquareRoute.kingdomToSquare() then
			return false
		end
	end
	SquarePage.tapBack(1200)
	if SquarePage.waitLeaveDialog(15000) then
		Logger.info(TAG .. " 已打开离开广场弹窗")
		return true
	end
	Logger.warn(TAG .. " 离开广场弹窗未出现")
	return false
end

--- 经弹窗或广场返回王国主城
--- @param timeoutMs number|nil
--- @return boolean
function SquareRoute.leaveDialogToKingdom(timeoutMs)
	timeoutMs = timeoutMs or 30000
	if KingdomPage.isKingdomHome() then
		return true
	end
	if SquarePage.isLeaveDialog() then
		SquarePage.tapReturnKingdom(1200)
	elseif SquarePage.isCurrent() then
		SquarePage.tapBack(1000)
		if SquarePage.waitLeaveDialog(8000) then
			SquarePage.tapReturnKingdom(1200)
		end
	end
	if waitKingdom(timeoutMs) then
		Logger.info(TAG .. " 已回王国主城")
		return true
	end
	Logger.warn(TAG .. " 回王国主城超时")
	return false
end

--- @return boolean
function SquareRoute.isSquareContext()
	return SquarePage.isCurrent() or SquarePage.isLeaveDialog()
end

return SquareRoute