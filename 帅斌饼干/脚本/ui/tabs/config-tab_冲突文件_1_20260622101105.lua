--[[
模块: 配置模块标签页
路径: ui.tabs.config-tab
功能: 矿山勘查、矿山开采、洗脆饼参数配置
依赖: ui.components, ui.biscuit-config-panel, lib.user-config
--]]

local Components = require("ui.components")
local BiscuitConfigPanel = require("ui.biscuit-config-panel")
local MiningConfigPanel = require("ui.mining-config-panel")
local SeasideMarketConfigPanel = require("ui.seaside-market-config-panel")
local UserConfig = require("lib.user-config")
local MineSession = require("game.常规_未知的地底矿山.模块_矿山勘查.勘查_会话")
local MiningSession = require("game.常规_未知的地底矿山.模块_矿山开采.开采_会话")

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

		UserConfig.set("mine", partial)
		local oreCards = miningPanel.save()
		if #oreCards == 0 then
			toast("至少选择一种矿石", 0, 0, 14)
		end
		biscuitPanel.save()
		local restockBufferSec = tonumber(imgui.getInputText(marketBufferInput))
		if restockBufferSec and restockBufferSec >= 0 then
			UserConfig.set("seasideMarket", { restockBufferSec = math.floor(restockBufferSec) })
		end
		local marketItems = marketPanel.save()
		if #marketItems == 0 then
			toast("海滩交易所未选择道具", 0, 0, 14)
		end
		UserConfig.save()

		local saved = UserConfig.get("mine")
		imgui.setInputText(targetInput , tostring(saved.targetFloor))
		imgui.setInputText(gapInput , tostring(saved.farGap))
		imgui.setInputText(pollInput , tostring(saved.ocrPollSec))
		imgui.setInputText(waitInput , tostring(saved.farWaitSec))
		imgui.setInputText(miningIntervalInput , tostring(saved.miningIntervalSec))
		miningPanel.refresh()

		local savedBiscuit = UserConfig.get("biscuit")
		imgui.setInputText(biscuitPanel.maxRollsInput, tostring(savedBiscuit.maxRolls))
		for i, widgets in ipairs(biscuitPanel.sumRuleWidgets) do
			local rule = savedBiscuit.sumRules and savedBiscuit.sumRules[i]
			if rule then
				imgui.setInputText(widgets.countInput, tostring(rule.count or 2))
			end
		end
		local savedMarket = UserConfig.get("seasideMarket")
		imgui.setInputText(marketBufferInput , tostring(savedMarket.restockBufferSec or 30))
		marketPanel.refresh()

		toast("配置已保存", 0, 0, 14)
	end)

	return true
end

return ConfigTab
