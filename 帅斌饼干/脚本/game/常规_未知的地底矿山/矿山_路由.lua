local Color = require("lib.color")
local Touch = require("lib.touch")
local Logger = require("lib.logger")

local KingdomPage = require("game.通用_王国.页面")
local MineHomePage = require("game.常规_未知的地底矿山.矿山首页_页面")
local MineVenturePage = require("game.常规_未知的地底矿山.模块_矿山勘查.勘查_页面")
local MiningPage = require("game.常规_未知的地底矿山.模块_矿山开采.开采_页面")

local Route = {}
local TAG = "[矿山路由]"

function Route.kingdomHomeToMineHome()
	KingdomPage.tapEventBtn()
	KingdomPage.tapMineBtn()
	
	return MineHomePage.wait()
end

function Route.mineHomeToMineVenture()
	MineHomePage.tapVenture()
	
	return MineVenturePage.waitMineVentureDomain()
end

--- @param fromCompletedTask boolean|nil 首页预检有已完成任务时为 true
--- @return boolean
function Route.mineHomeToMining(fromCompletedTask)
	MineHomePage.tapMining()
	
	if MineHomePage.waitGone() then
		return true
	end
	
	return false
end

function Route.mineVentureToMineHome()
	MineVenturePage.tapBackBtn()
	return MineHomePage.wait()
end

function Route.mineHomeToKingdom()
	MineHomePage.tapBack()
	return KingdomPage.wait()
end

--- 矿山相关任意页面 → 王国首页
--- @return boolean
function Route.returnToKingdom()
	if KingdomPage.isKingdomHome() then
		return true
	end

	if MiningPage.isMiningPage() or MiningPage.isRewardPage() or MiningPage.isSettlementRoute() then
		MiningPage.tapBackBtn()
		if not MineHomePage.wait() then
			Logger.warn(TAG .. " 开采页返回矿山首页超时")
		end
	end

	if MineHomePage.isCurrent() then
		if Route.mineHomeToKingdom() then
			Logger.info(TAG .. " 已回王国首页")
			return true
		end
		Logger.warn(TAG .. " 矿山首页返回王国超时")
		return false
	end

	if KingdomPage.isKingdomHome() then
		return true
	end

	Logger.warn(TAG .. " 回王国首页失败，当前页面未知")
	return false
end

return Route
