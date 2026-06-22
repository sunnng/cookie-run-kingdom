local Color = require("lib.color")
local Touch = require("lib.touch")
local Logger = require("lib.logger")

local KingdomFeatureLib = require("game.通用_王国.特征库")
local KingdomPage = require("game.通用_王国.页面")
local MarketPage = require("game.常规_海滩交易所.交易所_页面")

local Route = {}
local TAG = "[海滩交易所.路由]"

local KingdomEvent = KingdomFeatureLib.event()

local function isEventPage()
	return Color.match(KingdomEvent.feature)
end

local function waitEvent(timeoutMs)
	return Color.waitMatch(KingdomEvent.feature , timeoutMs or 30000 , 500 , 800)
end

function Route.enter()
	if MarketPage.isCurrent() then
		return true
	end
	if not isEventPage() then
		if not KingdomPage.isKingdomHome() then
			Logger.warn(TAG .. " 不在王国主城/活动页，无法进入")
			return false
		end
		KingdomPage.tapEventBtn()
		if not waitEvent(30000) then
			Logger.warn(TAG .. " 等待王国活动页超时")
			return false
		end
	end
	Touch.tapArea(KingdomEvent.seasideMarketBtn , 1200)
	if MarketPage.waitCurrent(30000 , 500) then
		Logger.info(TAG .. " 已进入海滩交易所")
		return true
	end
	Logger.warn(TAG .. " 进入海滩交易所超时")
	return false
end

function Route.leave()
	if KingdomPage.isKingdomHome() then
		return true
	end
	if MarketPage.isCurrent() then
		MarketPage.tapClose(1200)
	end
	if KingdomPage.wait(15000) then
		Logger.info(TAG .. " 已回王国主城")
		return true
	end
	if isEventPage() then
		Touch.pressBack(1200)
		if KingdomPage.wait(15000) then
			Logger.info(TAG .. " 已从活动页回王国主城")
			return true
		end
	end
	Logger.warn(TAG .. " 回王国主城失败")
	return false
end

function Route.isMarketContext()
	return MarketPage.isCurrent()
end

return Route
