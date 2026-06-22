--[[
模块: 洗脆饼配置面板
路径: ui.biscuit-config-panel
功能: 槽位规则、总和规则、最大洗练次数
依赖: ui.components, lib.user-config, game.功能_洗脆饼.词条库
--]]

local Components = require("ui.components")
local UserConfig = require("lib.user-config")
local 词条库 = require("game.功能_洗脆饼.词条库")

local BiscuitConfigPanel = {}

local NONE_LABEL = "（不选择）"
local TARGET_ROW_COUNT = 4
local SUM_RULE_ROW_COUNT = 4
local SLIDER_SCALE = 10

local function toTenths(value)
	local n = tonumber(value) or 0
	return math.floor(n * SLIDER_SCALE + 0.5)
end

local function fromTenths(tenths)
	return (tenths or 0) / SLIDER_SCALE
end

local function formatPercentDisplay(value)
	local n = tonumber(value)
	if not n then
		return "0%"
	end
	return string.format("%g%%", n)
end

local function clampTenths(tenths, minT, maxT)
	return math.max(minT, math.min(maxT, math.floor(tenths)))
end

local function boundsToTenths(minValue, maxValue)
	if not minValue or not maxValue then
		return 0, 0
	end
	return toTenths(minValue), toTenths(maxValue)
end

local function affixTenthsBounds(name)
	return boundsToTenths(词条库.valueBounds(name))
end

local function sumTenthsBounds(name, count)
	return boundsToTenths(词条库.sumBounds(name, count))
end

local function readSliderTenths(slider)
	if not slider then
		return 0
	end
	return imgui.getSliderPos(slider) or 0
end

local function refreshMinDisplay(widgets)
	if not widgets.slider then
		imgui.setWidgetText(widgets.valueLabel, "—")
		return
	end
	local tenths = readSliderTenths(widgets.slider)
	imgui.setWidgetText(widgets.valueLabel, formatPercentDisplay(fromTenths(tenths)))
end

local function setMinTenths(widgets, tenths)
	if not widgets.slider then
		return
	end
	tenths = clampTenths(tenths, widgets.minTenths, widgets.maxTenths)
	imgui.setSlider(widgets.slider, tenths)
	refreshMinDisplay(widgets)
end

local function setStepButtonsEnabled(widgets, enabled)
	if widgets.decBtn then
		imgui.setWidgetVisible(widgets.decBtn, enabled)
	end
	if widgets.incBtn then
		imgui.setWidgetVisible(widgets.incBtn, enabled)
	end
end

local function replaceSlider(widgets, minT, maxT, currentTenths)
	if widgets.slider then
		imgui.setWidgetVisible(widgets.slider, false)
		widgets.slider = nil
	end

	if minT >= maxT then
		widgets.minTenths = 0
		widgets.maxTenths = 0
		setStepButtonsEnabled(widgets, false)
		refreshMinDisplay(widgets)
		return
	end

	currentTenths = clampTenths(currentTenths, minT, maxT)
	local slider = imgui.createSlider(widgets.sliderSlot, "", minT, maxT, currentTenths, widgets.sliderWidth)
	widgets.minTenths = minT
	widgets.maxTenths = maxT
	widgets.slider = slider
	setStepButtonsEnabled(widgets, true)

	imgui.setOnSliderEvent(slider, function()
		refreshMinDisplay(widgets)
	end)
	refreshMinDisplay(widgets)
end

local function selectComboByName(combo, name)
	local count = imgui.getItemCount(combo) or 0
	local targetIdx = 0
	if type(name) == "string" and name ~= "" then
		for i = 0, count - 1 do
			if imgui.getItemText(combo, i) == name then
				targetIdx = i
				break
			end
		end
	end
	imgui.setItemSelected(combo, targetIdx)
end

local function createAffixCombo(parent, selectedName)
	local combo = imgui.createComboBox(parent, "", 200)
	imgui.addOptionItem(combo, NONE_LABEL)
	for _, affixName in ipairs(词条库.names()) do
		imgui.addOptionItem(combo, affixName)
	end
	selectComboByName(combo, selectedName)
	return combo
end

local function comboName(combo)
	local idx = imgui.getSelectedItemIndex(combo) or 0
	local name = imgui.getItemText(combo, idx) or NONE_LABEL
	if name == NONE_LABEL then
		return ""
	end
	return name
end

local function refreshRangeHint(combo, rangeLabel)
	imgui.setWidgetText(rangeLabel, 词条库.rangeHint(comboName(combo)))
end

local function readCountInput(countInput)
	local count = tonumber(imgui.getInputText(countInput))
	if not count then
		return 2
	end
	return math.min(4, math.max(1, math.floor(count)))
end

local function bindStepButtons(widgets)
	imgui.setOnClick(widgets.decBtn, function()
		setMinTenths(widgets, readSliderTenths(widgets.slider) - 1)
	end)
	imgui.setOnClick(widgets.incBtn, function()
		setMinTenths(widgets, readSliderTenths(widgets.slider) + 1)
	end)
end

local function createTargetBlock(parent, targetCfg)
	local row = imgui.createHorticalLayout(parent, -1, 80)
	imgui.setLayoutBorderVisible(row, true)
	imgui.setWidgetStyle(row, ImGuiStyleVar.ItemSpacing, 4, 0)

	local check = imgui.createCheckBox(row, "启用", false)
	imgui.setChecked(check, targetCfg.enabled == true)

	local combo = createAffixCombo(row, targetCfg.name)
	local rangeLabel = Components.textLabel(row, 词条库.rangeHint(targetCfg.name), 0, 0)

	Components.textLabel(row, "最低%:", 0, 0)
	local sliderSlot = imgui.createHorticalLayout(row, 140, 56)
	local valueLabel = Components.textLabel(row, formatPercentDisplay(targetCfg.minPercent), 0, 0)
	local decBtn = imgui.createButton(row, "-0.1", 0, 0)
	local incBtn = imgui.createButton(row, "+0.1", 0, 0)

	local widgets = {
		check = check,
		combo = combo,
		rangeLabel = rangeLabel,
		sliderSlot = sliderSlot,
		sliderWidth = 140,
		slider = nil,
		valueLabel = valueLabel,
		decBtn = decBtn,
		incBtn = incBtn,
		minTenths = 0,
		maxTenths = 0,
	}

	bindStepButtons(widgets)

	local minT, maxT = affixTenthsBounds(targetCfg.name)
	replaceSlider(widgets, minT, maxT, toTenths(targetCfg.minPercent))

	imgui.setOnSelectEvent(combo, function()
		local name = comboName(combo)
		local newMinT, newMaxT = affixTenthsBounds(name)
		local currentT
		if widgets.maxTenths <= 0 or not widgets.slider then
			currentT = newMinT
		else
			currentT = clampTenths(readSliderTenths(widgets.slider), newMinT, newMaxT)
		end
		replaceSlider(widgets, newMinT, newMaxT, currentT)
		refreshRangeHint(combo, rangeLabel)
	end)

	return widgets
end

local function refreshSumSliderRange(widgets)
	local name = comboName(widgets.combo)
	local count = readCountInput(widgets.countInput)
	local minT, maxT = sumTenthsBounds(name, count)
	local currentT
	if widgets.maxTenths <= 0 or not widgets.slider then
		currentT = minT
	else
		currentT = clampTenths(readSliderTenths(widgets.slider), minT, maxT)
	end
	replaceSlider(widgets, minT, maxT, currentT)
end

local function setCountInput(widgets, count)
	count = math.min(4, math.max(1, math.floor(count)))
	imgui.setInputText(widgets.countInput, tostring(count))
	refreshSumSliderRange(widgets)
end

local function createSumRuleBlock(parent, ruleCfg)
	local row = imgui.createHorticalLayout(parent, -1, 80)
	imgui.setLayoutBorderVisible(row, true)
	imgui.setWidgetStyle(row, ImGuiStyleVar.ItemSpacing, 4, 0)

	local check = imgui.createCheckBox(row, "启用", false)
	imgui.setChecked(check, ruleCfg.enabled == true)

	local combo = createAffixCombo(row, ruleCfg.name)
	local rangeLabel = Components.textLabel(row, 词条库.rangeHint(ruleCfg.name), 0, 0)

	Components.textLabel(row, "词条数等于:", 0, 0)
	local countInput = imgui.createInputText(row, "", tostring(ruleCfg.count or 2), 0, 60, 80)
	local countDecBtn = imgui.createButton(row, "-", 0, 0)
	local countIncBtn = imgui.createButton(row, "+", 0, 0)

	Components.textLabel(row, "总和大于等于:", 0, 0)
	local sliderSlot = imgui.createHorticalLayout(row, 120, 56)
	local valueLabel = Components.textLabel(row, formatPercentDisplay(ruleCfg.minSum), 0, 0)
	local decBtn = imgui.createButton(row, "-0.1", 0, 0)
	local incBtn = imgui.createButton(row, "+0.1", 0, 0)

	local widgets = {
		check = check,
		combo = combo,
		rangeLabel = rangeLabel,
		countInput = countInput,
		sliderSlot = sliderSlot,
		sliderWidth = 120,
		slider = nil,
		valueLabel = valueLabel,
		decBtn = decBtn,
		incBtn = incBtn,
		minTenths = 0,
		maxTenths = 0,
	}

	bindStepButtons(widgets)

	local count = ruleCfg.count or 2
	local minT, maxT = sumTenthsBounds(ruleCfg.name, count)
	replaceSlider(widgets, minT, maxT, toTenths(ruleCfg.minSum))

	imgui.setOnSelectEvent(combo, function()
		refreshRangeHint(combo, rangeLabel)
		refreshSumSliderRange(widgets)
	end)
	imgui.setOnClick(countDecBtn, function()
		setCountInput(widgets, readCountInput(countInput) - 1)
	end)
	imgui.setOnClick(countIncBtn, function()
		setCountInput(widgets, readCountInput(countInput) + 1)
	end)

	return widgets
end

local function loadList(list, count, fallback)
	if type(list) ~= "table" or #list == 0 then
		list = fallback
	end
	while #list < count do
		list[#list + 1] = {}
	end
	return list
end

--- @param parent userdata
--- @return table panel
function BiscuitConfigPanel.build(parent)
	Components.textLabel(parent, "毕业条件：槽位规则全部满足，或任一总和规则满足", 0, 0)

	Components.textLabel(parent, "—— 槽位规则（每条占一条副词条，按阈值从高到低匹配）——", 0, 0)
	local targets = loadList(UserConfig.get("biscuit").targets, TARGET_ROW_COUNT, {
		{ enabled = true, name = "冷却时间", minPercent = 5 },
		{ enabled = true, name = "会心", minPercent = 6 },
		{ enabled = false, name = "", minPercent = 0 },
		{ enabled = false, name = "", minPercent = 0 },
	})
	local targetWidgets = {}
	for i = 1, TARGET_ROW_COUNT do
		targetWidgets[i] = createTargetBlock(parent, targets[i] or {})
	end

	Components.textLabel(parent, "—— 总和规则（可选，同名词条≥条数，取最高 N 条求和达标）——", 0, 0)
	local sumRules = loadList(UserConfig.get("biscuit").sumRules, SUM_RULE_ROW_COUNT, {
		{ enabled = false, name = "", count = 2, minSum = 0 },
		{ enabled = false, name = "", count = 2, minSum = 0 },
		{ enabled = false, name = "", count = 2, minSum = 0 },
		{ enabled = false, name = "", count = 2, minSum = 0 },
	})
	local sumRuleWidgets = {}
	for i = 1, SUM_RULE_ROW_COUNT do
		sumRuleWidgets[i] = createSumRuleBlock(parent, sumRules[i] or {})
	end

	local biscuit = UserConfig.get("biscuit")
	local maxRollsInput = Components.labeledInput(parent, "最大洗练次数:", biscuit.maxRolls, 120, 80, true)

	local function save()
		local savedTargets = {}
		for i, widgets in ipairs(targetWidgets) do
			local minPercent = 0
			if widgets.slider then
				minPercent = fromTenths(readSliderTenths(widgets.slider))
			end
			savedTargets[i] = {
				enabled = imgui.isChecked(widgets.check),
				name = comboName(widgets.combo),
				minPercent = minPercent,
			}
		end

		local savedSumRules = {}
		for i, widgets in ipairs(sumRuleWidgets) do
			local minSum = 0
			if widgets.slider then
				minSum = fromTenths(readSliderTenths(widgets.slider))
			end
			savedSumRules[i] = {
				enabled = imgui.isChecked(widgets.check),
				name = comboName(widgets.combo),
				count = readCountInput(widgets.countInput),
				minSum = minSum,
			}
		end

		local maxRolls = tonumber(imgui.getInputText(maxRollsInput))
		local partial = {
			targets = savedTargets,
			sumRules = savedSumRules,
		}
		if maxRolls and maxRolls > 0 then
			partial.maxRolls = math.floor(maxRolls)
		end
		UserConfig.set("biscuit", partial)
	end

	return {
		maxRollsInput = maxRollsInput,
		targetWidgets = targetWidgets,
		sumRuleWidgets = sumRuleWidgets,
		save = save,
	}
end

return BiscuitConfigPanel
