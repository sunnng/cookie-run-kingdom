local Logger = require("lib.logger")
local UserConfig = require("lib.user-config")
local StatusHud = require("lib.status-hud")

local Route = require("game.常规_海滩交易所.交易所_路由")
local MarketPage = require("game.常规_海滩交易所.交易所_页面")
local Session = require("game.常规_海滩交易所.交易所_会话")

local Task = {}
local TAG = "[海滩交易所.任务]"

local function resolveItems()
	local cfg = UserConfig.get("seasideMarket") or {}
	if type(cfg.items) == "table" and #cfg.items > 0 then
		return cfg.items
	end
	return MarketPage.stockKeys()
end

local function scheduleFromPage()
	local restockSec , raw = MarketPage.readRestockSeconds()
	if restockSec and restockSec > 0 then
		Session.scheduleAfterRestock(restockSec)
		return true
	end
	if restockSec == 0 then
		Logger.info(TAG .. " 刷新按钮仍为免费刷新，不写等待")
		return false
	end
	Logger.warn(TAG .. " 未能读取补货时间 raw=" .. tostring(raw))
	return false
end

function Task.run()
	local cfg = UserConfig.get("seasideMarket") or {}
	if cfg.enabled ~= true then
		Logger.info(TAG .. " 任务未启用，跳过")
		return false
	end
	StatusHud.setTask("海滩交易所" , "进入中…")
	if not Route.enter() then
		return false
	end
	if not MarketPage.ensureItemTab() then
		Logger.warn(TAG .. " 未能确认道具交易所页")
		Route.leave()
		return false
	end
	
	local forceFirstRun = Session.consumeStartupBypass()
	StatusHud.setTask("海滩交易所" , "检查刷新…")
	if MarketPage.isFreeRefresh() then
		Logger.info(TAG .. " 可免费刷新，先刷新")
		StatusHud.setTask("海滩交易所" , "免费刷新…")
		MarketPage.tapRefresh()
	else
		local remain , raw = MarketPage.readRestockSeconds()
		if remain and remain > 0 then
			if forceFirstRun then
				Logger.info(TAG .. " 首轮强制扫货，忽略页面补货倒计时: " .. tostring(raw))
			else
				Logger.info(TAG .. " 当前冷却中，以 OCR 为准推迟: " .. tostring(raw))
				Session.scheduleAfterRestock(remain)
				Route.leave()
				return true
			end
		end
	end
	
	local items = resolveItems()
	Logger.info(TAG .. " 开始扫货: " .. table.concat(items , ","))
	StatusHud.setTask("海滩交易所" , "扫货中…")
	local stats = MarketPage.purchaseWishlist(items)
	Logger.info(string.format(
		TAG .. " 扫货结束 purchased=%d soldOut=%d shortage=%d failed=%d" ,
		stats.purchased ,
		stats.skipped.soldOut ,
		stats.skipped.shortage or 0 ,
		stats.skipped.failed
	))
	
	StatusHud.setTask("海滩交易所" , "读取补货…")
	scheduleFromPage()
	Route.leave()
	return true
end

return Task
