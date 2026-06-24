--[[
模块: 梦幻繁星岛路由
路径: game.常规_梦幻繁星岛.繁星岛_路由
功能: 导航到梦幻繁星岛首页
依赖: lib.color, lib.touch, lib.logger, game.通用_王国.特征库, game.常规_梦幻繁星岛.繁星岛_页面
--]]

local Color = require("lib.color")
local Touch = require("lib.touch")
local Logger = require("lib.logger")
local KingdomFeatureLib = require("game.通用_王国.特征库")
local KingdomPage = require("game.通用_王国.页面")
local StarlightPage = require("game.常规_梦幻繁星岛.繁星岛_页面")

local Route = {}
local TAG = "[梦幻繁星岛.路由]"

local kingdomHomeFeatures = KingdomFeatureLib.home()
local kingdomEventFeatures = KingdomFeatureLib.event()

function Route.isStarlightHome()
	return StarlightPage.isHomePage()
end

--- 从王国首页导航到梦幻繁星岛首页
--- @return boolean
function Route.kingdomToStarlightHome()
	if StarlightPage.isHomePage() then
		return true
	end

	if not KingdomPage.isKingdomHome() then
		Logger.warn(TAG .. " 当前不在王国首页，无法导航")
		return false
	end

	-- 1. 点击王国首页事件按钮
	local eventBtn = kingdomHomeFeatures.eventBtn
	if not eventBtn then
		Logger.warn(TAG .. " 王国 eventBtn 未配置")
		return false
	end
	Touch.tapArea(eventBtn , 1200)

	-- 2. 等待事件页
	if not Color.waitMatch(kingdomEventFeatures.feature , 10000 , 500) then
		Logger.warn(TAG .. " 等待事件页超时")
		return false
	end

	-- 3. 点击梦幻繁星岛按钮
	local starlightBtn = kingdomEventFeatures.梦幻繁星岛_按钮
	if not starlightBtn then
		Logger.warn(TAG .. " 梦幻繁星岛_按钮 未配置")
		return false
	end
	Touch.tapArea(starlightBtn , 1500)

	-- 4. 等待繁星岛首页
	return StarlightPage.waitHomePage(30000)
end

--- 确保位于繁星岛首页
--- @return boolean
function Route.ensureStarlightHome()
	if StarlightPage.isHomePage() then
		return true
	end
	return Route.kingdomToStarlightHome()
end

return Route
