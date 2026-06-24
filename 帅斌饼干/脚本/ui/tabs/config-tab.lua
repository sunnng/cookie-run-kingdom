--[[
模块: 配置模块标签页
路径: ui.tabs.config-tab
功能: 矿山勘查、矿山开采、洗脆饼参数配置
依赖: ui.components, ui.biscuit-config-panel, lib.user-config
--]]

local Components = require("ui.components")
local BiscuitConfigPanel = require("ui.biscuit-config-panel")
local MiningConfigPanel = require("ui.mining-config-panel")
local BattleConfigPanel = require("ui.battle-config-panel")
local SeasideMarketConfigPanel = require("ui.seaside-market-config-panel")
local UserConfig = require("lib.user-config")
local MineSession = require("game.常规_未知的地底矿山.模块_矿山勘查.勘查_会话")
local MiningSession = require("game.常规_未知的地底矿山.模块_矿山开采.开采_会话")
local JellySession = require("game.常规_未知的地底矿山.模块_解除洋菜冻.解除洋菜冻_会话")

local ConfigTab = {}

function ConfigTab.build(parent)
	local layout = imgui.createVerticalLayout(parent, -1, 0)

	local mineTree = imgui.createTreeBoxLayout(layout, "矿山勘查", -1)
	if not mineTree then
		print("创建树形框失败:", imgui.getLastError())
		return false
	end

	local mine = UserConfig.get("mine")

	local targetInput = Components.labeledInput(mineTree, "目标层数:", mine.targetFloor)
	local gapInput = Components.labeledInput(mineTree, "远距等待层数阈值:", mine.farGap)
	local pollInput = Components.labeledInput(mineTree, "OCR轮询间隔(秒):", mine.ocrPollSec)
	local waitInput = Components.labeledInput(mineTree, "远距等待时间(秒):", mine.farWaitSec)

	local sessionStatusLabel = Components.textLabel(mineTree, "会话: " .. MineSession.describe(), -1, 0)
	local sessionBtnRow = imgui.createHorticalLayout(mineTree, -1, 52)
	imgui.setLayoutBorderVisible(sessionBtnRow, false)
	local refreshSessionBtn = imgui.createButton(sessionBtnRow, "刷新会话状态", 0, 52)
	local clearSessionBtn = imgui.createButton(sessionBtnRow, "清除勘查会话", -1, 52)

	local function refreshSessionStatus()
		Components.setText(sessionStatusLabel, "会话: " .. MineSession.describe())
	end

	imgui.setOnClick(refreshSessionBtn, function()
		refreshSessionStatus()
		toast("会话状态已刷新", 0, 0, 14)
	end)

	imgui.setOnClick(clearSessionBtn, function()
		MineSession.clear()
		refreshSessionStatus()
		toast("勘查会话已清除", 0, 0, 14)
	end)

	local miningTree = imgui.createTreeBoxLayout(layout, "矿山开采", -1)
	if not miningTree then
		print("创建树形框失败:", imgui.getLastError())
		return false
	end

	local miningIntervalInput = Components.labeledInput(miningTree, "开采间隔(秒):", mine.miningIntervalSec)
	local miningPanel = MiningConfigPanel.build(miningTree)

	local miningSessionStatusLabel = Components.textLabel(miningTree, "会话: " .. MiningSession.describe(), -1, 0)
	local miningSessionBtnRow = imgui.createHorticalLayout(miningTree, -1, 52)
	imgui.setLayoutBorderVisible(miningSessionBtnRow, false)
	local refreshMiningSessionBtn = imgui.createButton(miningSessionBtnRow, "刷新会话状态", 0, 52)
	local clearMiningSessionBtn = imgui.createButton(miningSessionBtnRow, "清除开采会话", -1, 52)

	local function refreshMiningSessionStatus()
		Components.setText(miningSessionStatusLabel, "会话: " .. MiningSession.describe())
	end

	imgui.setOnClick(refreshMiningSessionBtn, function()
		refreshMiningSessionStatus()
		toast("开采会话状态已刷新", 0, 0, 14)
	end)

	imgui.setOnClick(clearMiningSessionBtn, function()
		MiningSession.clear()
		refreshMiningSessionStatus()
		toast("开采会话已清除", 0, 0, 14)
	end)

	local battleTree = imgui.createTreeBoxLayout(layout, "矿山战斗", -1)
	if not battleTree then
		print("创建树形框失败:", imgui.getLastError())
		return false
	end
	local battleIntervalInput = Components.labeledInput(battleTree, "战斗检测间隔(秒):", mine.battleIntervalSec or 21600)

	local BattleSession = require("game.常规_未知的地底矿山.模块_矿山战斗.战斗_会话")
	local battleSessionLabel = Components.textLabel(battleTree, "会话: " .. BattleSession.describe(mine.battleIntervalSec or 21600), -1, 0)
	local battleSessionBtnRow = imgui.createHorticalLayout(battleTree, -1, 52)
	imgui.setLayoutBorderVisible(battleSessionBtnRow, false)
	local refreshBattleSessionBtn = imgui.createButton(battleSessionBtnRow, "刷新会话状态", 0, 52)
	local clearBattleSessionBtn = imgui.createButton(battleSessionBtnRow, "清除战斗会话", -1, 52)

	local function refreshBattleSessionStatus()
		local interval = tonumber(imgui.getInputText(battleIntervalInput)) or 21600
		Components.setText(battleSessionLabel, "会话: " .. BattleSession.describe(interval))
	end

	imgui.setOnClick(refreshBattleSessionBtn, function()
		refreshBattleSessionStatus()
		toast("战斗会话状态已刷新", 0, 0, 14)
	end)

	imgui.setOnClick(clearBattleSessionBtn, function()
		BattleSession.clear()
		refreshBattleSessionStatus()
		toast("战斗会话已清除", 0, 0, 14)
	end)

	local battlePanel = BattleConfigPanel.build(battleTree)

	local jellyTree = imgui.createTreeBoxLayout(layout, "解除洋菜冻", -1)
	if not jellyTree then
		print("创建树形框失败:", imgui.getLastError())
		return false
	end
	local jellyIntervalInput = Components.labeledInput(jellyTree, "冷却间隔(秒):", mine.jellyIntervalSec or 3600)

	local jellySessionLabel = Components.textLabel(jellyTree, "会话: " .. JellySession.describe(), -1, 0)
	local jellySessionBtnRow = imgui.createHorticalLayout(jellyTree, -1, 52)
	imgui.setLayoutBorderVisible(jellySessionBtnRow, false)
	local refreshJellySessionBtn = imgui.createButton(jellySessionBtnRow, "刷新会话状态", 0, 52)
	local clearJellySessionBtn = imgui.createButton(jellySessionBtnRow, "清除解除洋菜冻会话", -1, 52)

	local function refreshJellySessionStatus()
		Components.setText(jellySessionLabel, "会话: " .. JellySession.describe())
	end

	imgui.setOnClick(refreshJellySessionBtn, function()
		refreshJellySessionStatus()
		toast("解除洋菜冻会话状态已刷新", 0, 0, 14)
	end)

	imgui.setOnClick(clearJellySessionBtn, function()
		JellySession.clear()
		refreshJellySessionStatus()
		toast("解除洋菜冻会话已清除", 0, 0, 14)
	end)

	local biscuitTree = imgui.createTreeBoxLayout(layout, "洗脆饼", -1)
	if not biscuitTree then
		print("创建树形框失败:", imgui.getLastError())
		return false
	end
	local biscuitPanel = BiscuitConfigPanel.build(biscuitTree)

	local marketTree = imgui.createTreeBoxLayout(layout, "海滩交易所", -1)
	if not marketTree then
		print("创建树形框失败:", imgui.getLastError())
		return false
	end
	local market = UserConfig.get("seasideMarket")
	local marketBufferInput = Components.labeledInput(marketTree, "补货缓冲(秒):", market.restockBufferSec or 30)
	local marketPanel = SeasideMarketConfigPanel.build(marketTree)

	local arenaTree = imgui.createTreeBoxLayout(layout, "王国竞技场", -1)
	if not arenaTree then
		print("创建树形框失败:", imgui.getLastError())
		return false
	end
	local arena = UserConfig.get("arena")
	local arenaMaxBattlesInput = Components.labeledInput(arenaTree, "战斗上限(空=无限):", arena.maxBattles or "")
	local arenaAutoBuyInput = Components.labeledInput(arenaTree, "自动买票次数:", arena.autoBuyCount or 0)
	local arenaTrophyDiffInput = Components.labeledInput(arenaTree, "奖杯差值阈值:", arena.trophyDiff or 0)

	local saveBtn = imgui.createButton(layout, "保存配置", -1, 52)
	imgui.setOnClick(saveBtn, function()
		local partial = {}
		local targetFloor = tonumber(imgui.getInputText(targetInput))
		if targetFloor and targetFloor > 0 then
			partial.targetFloor = math.floor(targetFloor)
		end
		local farGap = tonumber(imgui.getInputText(gapInput))
		if farGap and farGap >= 0 then
			partial.farGap = math.floor(farGap)
		end
		local ocrPollSec = tonumber(imgui.getInputText(pollInput))
		if ocrPollSec and ocrPollSec >= 10 then
			partial.ocrPollSec = math.floor(ocrPollSec)
		end
		local farWaitSec = tonumber(imgui.getInputText(waitInput))
		if farWaitSec and farWaitSec >= 60 then
			partial.farWaitSec = math.floor(farWaitSec)
		end
		local miningIntervalSec = tonumber(imgui.getInputText(miningIntervalInput))
		if miningIntervalSec and miningIntervalSec >= 60 then
			partial.miningIntervalSec = math.floor(miningIntervalSec)
		end
		local battleIntervalSec = tonumber(imgui.getInputText(battleIntervalInput))
		if battleIntervalSec and battleIntervalSec >= 60 then
			partial.battleIntervalSec = math.floor(battleIntervalSec)
		end
		local jellyIntervalSec = tonumber(imgui.getInputText(jellyIntervalInput))
		if jellyIntervalSec and jellyIntervalSec >= 60 then
			partial.jellyIntervalSec = math.floor(jellyIntervalSec)
		end

		local oreCards = miningPanel.save()
		if #oreCards == 0 then
			toast("至少选择一种矿石", 0, 0, 14)
		end
		local battleCfg = battlePanel.save()
		for k, v in pairs(battleCfg) do
			partial[k] = v
		end
		UserConfig.set("mine", partial)
		biscuitPanel.save()
		local restockBufferSec = tonumber(imgui.getInputText(marketBufferInput))
		if restockBufferSec and restockBufferSec >= 0 then
			UserConfig.set("seasideMarket", { restockBufferSec = math.floor(restockBufferSec) })
		end
		local marketItems = marketPanel.save()
		if #marketItems == 0 then
			toast("海滩交易所未选择道具", 0, 0, 14)
		end
		local maxBattlesText = imgui.getInputText(arenaMaxBattlesInput)
		local arenaPartial = {}
		if maxBattlesText and maxBattlesText:gsub("%s+", "") ~= "" then
			local maxBattles = tonumber(maxBattlesText)
			if maxBattles and maxBattles > 0 then
				arenaPartial.maxBattles = math.floor(maxBattles)
			end
		else
			arenaPartial.maxBattles = nil
		end
		local autoBuyCount = tonumber(imgui.getInputText(arenaAutoBuyInput))
		if autoBuyCount and autoBuyCount >= 0 then
			arenaPartial.autoBuyCount = math.floor(autoBuyCount)
		end
		local trophyDiff = tonumber(imgui.getInputText(arenaTrophyDiffInput))
		if trophyDiff and trophyDiff >= 0 then
			arenaPartial.trophyDiff = math.floor(trophyDiff)
		end
		UserConfig.set("arena", arenaPartial)
		UserConfig.save()

		local saved = UserConfig.get("mine")
		imgui.setInputText(targetInput, tostring(saved.targetFloor))
		imgui.setInputText(gapInput, tostring(saved.farGap))
		imgui.setInputText(pollInput, tostring(saved.ocrPollSec))
		imgui.setInputText(waitInput, tostring(saved.farWaitSec))
		imgui.setInputText(miningIntervalInput, tostring(saved.miningIntervalSec))
		imgui.setInputText(battleIntervalInput, tostring(saved.battleIntervalSec or 21600))
		imgui.setInputText(jellyIntervalInput, tostring(saved.jellyIntervalSec or 3600))
		miningPanel.refresh()
		battlePanel.refresh()

		local savedBiscuit = UserConfig.get("biscuit")
		imgui.setInputText(biscuitPanel.maxRollsInput, tostring(savedBiscuit.maxRolls))
		for i, widgets in ipairs(biscuitPanel.sumRuleWidgets) do
			local rule = savedBiscuit.sumRules and savedBiscuit.sumRules[i]
			if rule then
				imgui.setInputText(widgets.countInput, tostring(rule.count or 2))
			end
		end
		local savedMarket = UserConfig.get("seasideMarket")
		imgui.setInputText(marketBufferInput, tostring(savedMarket.restockBufferSec or 30))
		marketPanel.refresh()

		local savedArena = UserConfig.get("arena")
		imgui.setInputText(arenaMaxBattlesInput, savedArena.maxBattles and tostring(savedArena.maxBattles) or "")
		imgui.setInputText(arenaAutoBuyInput, tostring(savedArena.autoBuyCount or 0))
		imgui.setInputText(arenaTrophyDiffInput, tostring(savedArena.trophyDiff or 0))

		toast("配置已保存", 0, 0, 14)
	end)

	return true
end

return ConfigTab
