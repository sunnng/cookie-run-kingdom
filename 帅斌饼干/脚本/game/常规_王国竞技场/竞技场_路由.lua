local Touch = require("lib.touch")
local Logger = require("lib.logger")
local Ocr = require("lib.ocr")

local KingdomPage = require("game.通用_王国.页面")
local KingdomFeatureLib = require("game.通用_王国.特征库")
local ArenaPage = require("game.常规_王国竞技场.竞技场_页面")

local Route = {}
local TAG = "[王国竞技场.路由]"
local arenaOcr = KingdomFeatureLib.adventure().arenaOcr

function Route.enter()
	if ArenaPage.isLobby() then
		Logger.info(TAG .. " 已在大厅，跳过导航")
		return true
	end

	if not KingdomPage.isAdventurePage() then
		if not KingdomPage.isKingdomHome() then
			Logger.warn(TAG .. " 不在王国主城，无法进入")
			return false
		end
		Logger.info(TAG .. " 王国主城 → 点击冒险")
		KingdomPage.tapAdventureBtn()
		if not KingdomPage.waitAdventure(30000) then
			Logger.warn(TAG .. " 等待冒险页超时")
			return false
		end
		Logger.info(TAG .. " 已进入冒险页")
	end

	Logger.info(TAG .. " OCR 查找并点击「王国竞技场」")
	if not Ocr.waitTap("王国竞技场" , arenaOcr , 30000 , 500 , 1000) then
		Logger.warn(TAG .. " 未能点击王国竞技场")
		return false
	end

	if ArenaPage.waitLobby(30000) then
		Logger.info(TAG .. " 已进入竞技场大厅")
		return true
	end
	Logger.warn(TAG .. " 等待竞技场大厅超时")
	return false
end

function Route.leave()
	if KingdomPage.isKingdomHome() then
		Logger.info(TAG .. " 已在王国首页，无需离开")
		return true
	end
	Logger.info(TAG .. " 离开竞技场")
	if ArenaPage.isLobby() then
		Logger.debug(TAG .. " 关闭竞技场大厅")
		ArenaPage.tapClose(1200)
	end
	if KingdomPage.isAdventurePage() then
		Logger.debug(TAG .. " 冒险页按返回")
		Touch.pressBack(1200)
	end
	if KingdomPage.wait(15000) then
		Logger.info(TAG .. " 已回到王国首页")
		return true
	end
	Logger.warn(TAG .. " 离开竞技场超时")
	return false
end

return Route
