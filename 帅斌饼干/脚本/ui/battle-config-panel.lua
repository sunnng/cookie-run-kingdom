--[[
模块: 矿山战斗配置面板
路径: ui.battle-config-panel
功能: 灵魂石类型多选（按类别水平平铺），提供全选/全部取消按钮
依赖: ui.components, lib.user-config
--]]

local Components = require("ui.components")
local UserConfig = require("lib.user-config")

local BattleConfigPanel = {}

--- 可选灵魂石列表（按类别分组；键名同矿山_特征库.battle.灵魂石类型）
local SOUL_STONE_OPTIONS = {
	{ name = "史诗" , options = {
		{ key = "浓缩奶油" , label = "浓缩奶油" } ,
		{ key = "牡蛎" , label = "牡蛎" } ,
		{ key = "雪酪" , label = "雪酪" } ,
		{ key = "辣椒素" , label = "辣椒素" } ,
		{ key = "闪耀之星" , label = "闪耀之星" } ,
		{ key = "绯红珊瑚" , label = "绯红珊瑚" } ,
		{ key = "妖精王" , label = "妖精王" } ,
		{ key = "星辰" , label = "星辰" } ,
	} } ,
	{ name = "传奇" , options = {
		{ key = "雷神武将" , label = "雷神武将" } ,
		{ key = "冰霜女王" , label = "冰霜女王" } ,
		{ key = "海妖精" , label = "海妖精" } ,
	} } ,
	{ name = "上古" , options = {
		{ key = "莓果" , label = "莓果" } ,
	} } ,
}

--- @param keys string[]|nil
--- @return table<string, boolean>
local function setFromKeys(keys)
	local enabled = {}
	if type(keys) == "table" then
		for _ , key in ipairs(keys) do
			enabled[key] = true
		end
	end
	return enabled
end

--- @param parent userdata
--- @return table panel
function BattleConfigPanel.build(parent)
	local mine = UserConfig.get("mine")
	local enabled = setFromKeys(mine.battleSoulStones)
	local checkboxes = {}

	-- 顶部按钮行
	local btnRow = imgui.createHorticalLayout(parent , - 1 , 76)
	imgui.setLayoutBorderVisible(btnRow , false)
	imgui.setWidgetStyle(btnRow , ImGuiStyleVar.ItemSpacing , 8 , 0)
	local selectAllBtn = imgui.createButton(btnRow , "全选" , 0 , 52)
	local clearAllBtn = imgui.createButton(btnRow , "全部取消" , 0 , 52)

	-- 按类别水平平铺展示灵魂石复选框
	for _ , group in ipairs(SOUL_STONE_OPTIONS) do
		local row = imgui.createHorticalLayout(parent , - 1 , 80)
		imgui.setLayoutBorderVisible(row , true)
		imgui.setWidgetStyle(row , ImGuiStyleVar.ItemSpacing , 8 , 0)
		Components.textLabel(row , "[" .. group.name .. "]" , 0 , 0)

		for _ , opt in ipairs(group.options) do
			local cb = imgui.createCheckBox(row , opt.label)
			imgui.setChecked(cb , enabled[opt.key] == true)
			checkboxes[opt.key] = cb
		end
	end

	local panel = {
		checkboxes = checkboxes ,
	}

	imgui.setOnClick(selectAllBtn , function()
		for _ , cb in pairs(checkboxes) do
			imgui.setChecked(cb , true)
		end
	end)

	imgui.setOnClick(clearAllBtn , function()
		for _ , cb in pairs(checkboxes) do
			imgui.setChecked(cb , false)
		end
	end)

	function panel.save()
		local list = {}
		for _ , group in ipairs(SOUL_STONE_OPTIONS) do
			for _ , opt in ipairs(group.options) do
				local cb = checkboxes[opt.key]
				if cb and imgui.isChecked(cb) then
					list[#list + 1] = opt.key
				end
			end
		end
		return {
			battleSoulStones = list ,
		}
	end

	function panel.refresh()
		local saved = setFromKeys(UserConfig.get("mine").battleSoulStones)
		for key , cb in pairs(checkboxes) do
			imgui.setChecked(cb , saved[key] == true)
		end
	end

	return panel
end

return BattleConfigPanel
