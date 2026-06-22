--[[
模块: 功能模块标签页
路径: ui.tabs.feature-tab
功能: 功能开关
依赖: ui.components, lib.user-config
--]]

local Components = require("ui.components")
local UserConfig = require("lib.user-config")
local SquareSession = require("game.常规_布谷鸟广场.广场_会话")
local SeasideMarketSession = require("game.常规_海滩交易所.交易所_会话")
local ArenaSession = require("game.常规_王国竞技场.竞技场_会话")

local FeatureTab = {}

local function bindMineSurveyCheckbox(handle)
	local mine = UserConfig.get("mine")
	imgui.setChecked(handle, mine.surveyEnabled == true)
	imgui.setOnCheck(handle, function(_, checked)
		UserConfig.set("mine", { surveyEnabled = checked })
		UserConfig.save()
	end)
end

local function bindMineMiningCheckbox(handle)
	local mine = UserConfig.get("mine")
	imgui.setChecked(handle, mine.miningEnabled == true)
	imgui.setOnCheck(handle, function(_, checked)
		UserConfig.set("mine", { miningEnabled = checked })
		UserConfig.save()
	end)
end

local function bindBiscuitRerollCheckbox(handle)
	local biscuit = UserConfig.get("biscuit")
	imgui.setChecked(handle, biscuit.enabled == true)
	imgui.setOnCheck(handle, function(_, checked)
		UserConfig.set("biscuit", { enabled = checked })
		UserConfig.save()
	end)
end

local function bindSquareCheckbox(handle)
	local square = UserConfig.get("square")
	imgui.setChecked(handle, square.enabled == true)
	imgui.setOnCheck(handle, function(_, checked)
		UserConfig.set("square", { enabled = checked })
		UserConfig.save()
	end)
end

local function bindSeasideMarketCheckbox(handle)
	local market = UserConfig.get("seasideMarket")
	imgui.setChecked(handle, market and market.enabled == true)
	imgui.setOnCheck(handle, function(_, checked)
		UserConfig.set("seasideMarket", { enabled = checked })
		UserConfig.save()
	end)
end

local function bindArenaCheckbox(handle)
	local arena = UserConfig.get("arena")
	imgui.setChecked(handle, arena and arena.enabled == true)
	imgui.setOnCheck(handle, function(_, checked)
		UserConfig.set("arena", { enabled = checked })
		UserConfig.save()
	end)
end

function FeatureTab.build(parent)
	local layout = imgui.createVerticalLayout(parent, -1, 0)

	local squareRow = imgui.createHorticalLayout(layout, -1, 80)
	imgui.setLayoutBorderVisible(squareRow, true)
	Components.textLabel(squareRow, "[广场]", 0, 0)
	bindSquareCheckbox(imgui.createCheckBox(squareRow, "布谷鸟挂机"))
	local squareSessionLabel = Components.textLabel(squareRow, "状态: " .. SquareSession.describe(), 0, 0)
	local refreshSquareSessionBtn = imgui.createButton(squareRow, "刷新", 120, 52)
	local clearSquareSessionBtn = imgui.createButton(squareRow, "重置", 120, 52)

	local function refreshSquareSessionStatus()
		Components.setText(squareSessionLabel, "状态: " .. SquareSession.describe())
	end

	imgui.setOnClick(refreshSquareSessionBtn, function()
		refreshSquareSessionStatus()
		toast("广场状态已刷新", 0, 0, 14)
	end)

	imgui.setOnClick(clearSquareSessionBtn, function()
		SquareSession.clearAll()
		refreshSquareSessionStatus()
		toast("广场session已清除", 0, 0, 14)
	end)

	local mineRow = imgui.createHorticalLayout(layout, -1, 80)
	imgui.setLayoutBorderVisible(mineRow, true)
	Components.textLabel(mineRow, "[矿山]", 0, 0)
	bindMineSurveyCheckbox(imgui.createCheckBox(mineRow, "勘查"))
	bindMineMiningCheckbox(imgui.createCheckBox(mineRow, "开采"))

	local biscuitRow = imgui.createHorticalLayout(layout, -1, 80)
	imgui.setLayoutBorderVisible(biscuitRow, true)
	Components.textLabel(biscuitRow, "[脆饼]", 0, 0)
	bindBiscuitRerollCheckbox(imgui.createCheckBox(biscuitRow, "洗脆饼"))

	local marketRow = imgui.createHorticalLayout(layout, -1, 80)
	imgui.setLayoutBorderVisible(marketRow, true)
	Components.textLabel(marketRow, "[交易所]", 0, 0)
	bindSeasideMarketCheckbox(imgui.createCheckBox(marketRow, "海滩交易所"))
	local marketSessionLabel = Components.textLabel(marketRow, "状态: " .. SeasideMarketSession.describe(), 0, 0)
	local refreshMarketSessionBtn = imgui.createButton(marketRow, "刷新", 120, 52)
	local clearMarketSessionBtn = imgui.createButton(marketRow, "重置", 120, 52)

	local function refreshMarketSessionStatus()
		Components.setText(marketSessionLabel, "状态: " .. SeasideMarketSession.describe())
	end

	imgui.setOnClick(refreshMarketSessionBtn, function()
		refreshMarketSessionStatus()
		toast("交易所状态已刷新", 0, 0, 14)
	end)

	imgui.setOnClick(clearMarketSessionBtn, function()
		SeasideMarketSession.clear()
		refreshMarketSessionStatus()
		toast("交易所session已清除", 0, 0, 14)
	end)

	local arenaRow = imgui.createHorticalLayout(layout, -1, 80)
	imgui.setLayoutBorderVisible(arenaRow, true)
	Components.textLabel(arenaRow, "[竞技场]", 0, 0)
	bindArenaCheckbox(imgui.createCheckBox(arenaRow, "王国竞技场"))
	local arenaSessionLabel = Components.textLabel(arenaRow, "状态: " .. ArenaSession.describe(), 0, 0)
	local refreshArenaSessionBtn = imgui.createButton(arenaRow, "刷新", 120, 52)
	local clearArenaSessionBtn = imgui.createButton(arenaRow, "重置", 120, 52)

	local function refreshArenaSessionStatus()
		Components.setText(arenaSessionLabel, "状态: " .. ArenaSession.describe())
	end

	imgui.setOnClick(refreshArenaSessionBtn, function()
		refreshArenaSessionStatus()
		toast("竞技场状态已刷新", 0, 0, 14)
	end)

	imgui.setOnClick(clearArenaSessionBtn, function()
		ArenaSession.clear()
		refreshArenaSessionStatus()
		toast("竞技场session已清除", 0, 0, 14)
	end)
end

return FeatureTab
