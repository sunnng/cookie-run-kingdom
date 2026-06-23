local Color = require("lib.color")
local Touch = require("lib.touch")
local Ocr = require("lib.ocr")
local Logger = require("lib.logger")
local Guard = require("core.guard")
local DialogLib = require("lib.dialog")

local Features = require("game.常规_海滩交易所.交易所_坐标库")

local MarketPage = {}
local TAG = "[海滩交易所.页面]"

local Page = Features.page or {}
local Dialog = Features.dialogConfirm or Features.confirmDialog or {}
local ShortageDialog = Features.itemShortageDialog or {}
local List = Features.list or {}
local Slot = Features.slot or {}
local Stock = Features.stock or Features.Stock or {}

local DEDUP_RADIUS = 80
local DEFAULT_MAX_SWIPES = 20

local function hasFeature(feature)
	return type(feature) == "table" and feature[1] ~= nil
end

local function sortByX(points)
	table.sort(points , function(a , b)
		return a.x < b.x
	end)
	return points
end

local function isNearExisting(pt , list , radius)
	radius = radius or DEDUP_RADIUS
	local r2 = radius * radius
	for _ , p in ipairs(list or {}) do
		local dx = pt.x - p.x
		local dy = pt.y - p.y
		if dx * dx + dy * dy <= r2 then
			return true
		end
	end
	return false
end

local function slotBtnCenter(pt)
	return pt.x , pt.y + (Slot.buyBtnOffsetY or 110)
end

local function slotTapRect(pt)
	local cx , cy = slotBtnCenter(pt)
	local halfW = Slot.buyBtnHalfW or 105
	local halfH = Slot.buyBtnHalfH or 24
	return {cx - halfW , cy - halfH , cx + halfW , cy + halfH}
end

local function slotCrateRect(pt)
	local halfW = Slot.crateHalfW or 90
	local halfH = Slot.crateHalfH or 65
	local cy = pt.y + (Slot.crateOffsetY or -20)
	return {pt.x - halfW , cy - halfH , pt.x + halfW , cy + halfH}
end

local function configuredItems(itemKeys)
	local out = {}
	for _ , key in ipairs(itemKeys or {}) do
		local def = Stock[key]
		if hasFeature(def) then
			out[#out + 1] = {key = key , def = def}
		else
			Logger.warn(TAG .. " 未配置 Stock: " .. tostring(key))
		end
	end
	return out
end

function MarketPage.stockKeys()
	local keys = {}
	for key , def in pairs(Stock) do
		if hasFeature(def) then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys)
	return keys
end

function MarketPage.isCurrent()
	return hasFeature(Page.feature) and Color.match(Page.feature)
end

function MarketPage.waitCurrent(timeoutMs , intervalMs)
	if not hasFeature(Page.feature) then
		Logger.warn(TAG .. " page.feature 未配置")
		return false
	end
	return Color.waitMatch(Page.feature , timeoutMs or 30000 , intervalMs or 500 , 1000)
end

function MarketPage.tapClose(delayMs)
	Touch.tapArea(Page.closeBtn or {1530 , 14 , 1584 , 77} , delayMs or 1000)
end

function MarketPage.ensureItemTab()
	local tab = Features.tab and Features.tab.itemExchange
	if not tab then
		return MarketPage.isCurrent()
	end
	if hasFeature(tab.selectedFeature) and Color.match(tab.selectedFeature) then
		return true
	end
	if tab.area then
		Touch.tapArea(tab.area , 800)
	end
	return MarketPage.isCurrent()
end

local function hasNextPage()
	return hasFeature(List.arrowRight) and Color.find(List.arrowRight) ~= nil
end

function MarketPage.isLastPage()
	return hasFeature(List.arrowRight) and not hasNextPage()
end

function MarketPage.swipeNextPage()
	local swipe = List.swipe or {x1 = 1480 , y1 = 680 , x2 = 150 , y2 = 680 , moveMs = 600 , holdMs = 500 , downMs = 50}
	if MarketPage.isLastPage() then
		Logger.info(TAG .. " 右箭头不可见，列表已到右侧尽头")
		return false
	end
	Touch.swipeEx(swipe)
	Guard.sleep(700 , 300)
	return true
end

function MarketPage.isSlotSoldOut(pt)
	return Ocr.has("售罄" , slotCrateRect(pt))
end

function MarketPage.isConfirmDialog()
	return hasFeature(Dialog.feature) and Color.match(Dialog.feature)
end

function MarketPage.waitConfirmDialog(timeoutMs , intervalMs)
	if not hasFeature(Dialog.feature) then
		Logger.warn(TAG .. " confirmDialog.feature 未配置")
		return false
	end
	return Color.waitMatch(Dialog.feature , timeoutMs or 5000 , intervalMs or 300)
end

function MarketPage.tapDialogClose(delayMs)
	local btn = Dialog.cancelBtn or Dialog.closeBtn
	if btn then
		Touch.tapArea(btn , delayMs or 800)
		return true
	end
	return false
end

function MarketPage.isItemShortageDialog()
	return hasFeature(ShortageDialog.feature) and Color.match(ShortageDialog.feature)
end

function MarketPage.tapItemShortageCancel(delayMs)
	local btn = ShortageDialog.cancelBtn or ShortageDialog.closeBtn
	if not btn then
		Logger.warn(TAG .. " itemShortageDialog.cancelBtn 未配置")
		return false
	end
	Touch.tapArea(btn , delayMs or 800)
	return true
end

function MarketPage.tapShelfAndResolve(pt)
	local confirmDialog = DialogLib.new(Dialog , { tag = TAG })
	local shortageDialog = DialogLib.new(ShortageDialog , { tag = TAG })

	Touch.tapArea(slotTapRect(pt) , 800)

	local ok , outcome , reason = DialogLib.resolveAfterPrimary({
		primary = {
			dialog = confirmDialog ,
			opts = {
				mode = "flow" ,
				action = "confirm" ,
				waitAppearMs = 5000 ,
				required = true ,
				intervalMs = 300 ,
			} ,
		} ,
		watch = {
			{
				dialog = shortageDialog ,
				opts = { action = "cancel" , waitGoneMs = 2000 , intervalMs = 300 } ,
				result = "shortage" ,
				after = function()
					if confirmDialog:isVisible() then
						confirmDialog:handle({
							mode = "ifVisible" ,
							action = "cancel" ,
							waitGoneMs = 3000 ,
							intervalMs = 300 ,
						})
					end
				end ,
			} ,
		} ,
		successWhen = function()
			return not confirmDialog:isVisible()
		end ,
		successResult = "purchased" ,
		timeoutMs = 5000 ,
		intervalMs = 300 ,
		tag = TAG ,
	})

	if not ok then
		if reason == "not_visible" then
			Logger.warn(TAG .. " 点击货架后确认弹窗未出现")
		else
			Logger.warn(TAG .. " 购买确认后结果未知，尝试关闭确认弹窗 | " .. tostring(reason))
			confirmDialog:handle({
				mode = "ifVisible" ,
				action = "cancel" ,
				waitGoneMs = 3000 ,
				intervalMs = 300 ,
			})
		end
		return "failed"
	end

	if outcome == "shortage" then
		Logger.info(TAG .. " 命中道具不足弹窗，取消本次购买")
	end
	return outcome
end

function MarketPage.isFreeRefresh()
	local rect = Page.refreshOcr or Page.refreshStatusOcr
	return rect and Ocr.has("免费刷新" , rect)
end

function MarketPage.readRestockSeconds()
	local rect = Page.refreshOcr or Page.refreshStatusOcr
	if not rect then
		Logger.warn(TAG .. " refreshOcr 未配置")
		return nil
	end
	local text = Ocr.text(rect , "text")
	if not text or text == "" then
		return nil , text
	end
	if text:find("免费刷新" , 1 , true) then
		return 0 , text
	end
	local h , m , s = text:match("(%d+):(%d+):(%d+)")
	if h then
		return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) , text
	end
	Logger.warn(TAG .. " 补货倒计时 OCR 解析失败: " .. tostring(text))
	return nil , text
end

function MarketPage.tapRefresh()
	if not Page.refreshBtn then
		Logger.warn(TAG .. " refreshBtn 未配置")
		return false
	end
	Touch.tapArea(Page.refreshBtn , 1200)
	Guard.sleep(1000 , 300)
	if Page.refreshOcr or Page.refreshStatusOcr then
		Color.waitGone(function()
			return MarketPage.isFreeRefresh()
		end , 10000 , 500)
	end
	return true
end

local function collectVisibleTargets(itemDefs)
	local points = {}
	local seen = {}
	for _ , item in ipairs(itemDefs) do
		local found = Color.findAll(item.def)
		for _ , pt in ipairs(found) do
			if not isNearExisting(pt , seen) then
				seen[#seen + 1] = pt
				points[#points + 1] = {x = pt.x , y = pt.y , key = item.key}
			end
		end
	end
	return sortByX(points)
end

function MarketPage.purchaseWishlist(itemKeys)
	local stats = {
		purchased = 0 ,
		skipped = {
			soldOut = 0 ,
			shortage = 0 ,
			failed = 0 ,
		}
	}
	local itemDefs = configuredItems(itemKeys)
	if #itemDefs == 0 then
		Logger.warn(TAG .. " 无可购买道具配置")
		return stats
	end

	local swipes = 0
	while swipes <= (List.maxSwipes or DEFAULT_MAX_SWIPES) do
		local visited = {}
		local points = collectVisibleTargets(itemDefs)
		Logger.info(string.format(TAG .. " 扫描可见商品 目标命中:%d 滑动:%d" , #points , swipes))
		if #points > 0 then
			for _ , pt in ipairs(points) do
				if not isNearExisting(pt , visited) then
					visited[#visited + 1] = pt
					if MarketPage.isSlotSoldOut(pt) then
						stats.skipped.soldOut = stats.skipped.soldOut + 1
						Logger.info(TAG .. " " .. tostring(pt.key) .. " 已售罄，跳过")
					else
						Logger.info(TAG .. " 尝试购买 " .. tostring(pt.key))
						local result = MarketPage.tapShelfAndResolve(pt)
						if result == "purchased" then
							stats.purchased = stats.purchased + 1
						elseif result == "shortage" then
							stats.skipped.shortage = stats.skipped.shortage + 1
						else
							stats.skipped.failed = stats.skipped.failed + 1
						end
					end
				end
			end
		end
		if MarketPage.isLastPage() then
			Logger.info(TAG .. " 已是最后一页，结束扫货")
			break
		end
		if not MarketPage.swipeNextPage() then
			break
		end
		swipes = swipes + 1
	end
	return stats
end

return MarketPage
