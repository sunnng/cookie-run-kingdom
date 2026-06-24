--[[
模块: 矿山开采配置面板
路径: ui.mining-config-panel
功能: 矿石种类勾选（列表顺序即选卡优先级）
依赖: ui.components, lib.user-config
--]]

local Components = require("ui.components")
local UserConfig = require("lib.user-config")

local MiningConfigPanel = {}

--- 与特征库 oreVeinCards 键名一致；列表顺序即优先顺序
local ORE_OPTIONS = {
	{ key = "butterAmber" , label = "奶油琥珀石(不建议勾选,建议手动开采)" } ,
	{ key = "amberFossil" , label = "琥珀化石（黄）" } ,
	{ key = "sugarOre" , label = "糖矿石（蓝）" } ,
	{ key = "purpleFossil" , label = "紫化石（紫）" } ,
	{ key = "emeraldFossil" , label = "绿化石（绿）" } ,
	{ key = "flourStone" , label = "面粉石（白）" } ,
}

--- @param enabledKeys table<string, boolean>
--- @return string[]
local function keysFromSet(enabledKeys)
	local list = {}
	for _ , opt in ipairs(ORE_OPTIONS) do
		if enabledKeys[opt.key] then
			list[#list + 1] = opt.key
		end
	end
	return list
end

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
function MiningConfigPanel.build(parent)
	Components.textLabel(parent , "矿石种类（从上到下为优先顺序）" , - 1 , 0)

	local mine = UserConfig.get("mine")
	local enabled = setFromKeys(mine.miningOreCards)
	local checkboxes = {}

	for _ , opt in ipairs(ORE_OPTIONS) do
		local row = imgui.createHorticalLayout(parent , - 1 , 52)
		imgui.setLayoutBorderVisible(row , false)
		local cb = imgui.createCheckBox(row , opt.label)
		imgui.setChecked(cb , enabled[opt.key] == true)
		checkboxes[opt.key] = cb
	end

	local panel = {
		checkboxes = checkboxes ,
	}

	function panel.save()
		local list = {}
		for _ , opt in ipairs(ORE_OPTIONS) do
			local cb = checkboxes[opt.key]
			if cb and imgui.isChecked(cb) then
				list[#list + 1] = opt.key
			end
		end
		UserConfig.set("mine" , { miningOreCards = list })
		return list
	end

	function panel.refresh()
		local saved = setFromKeys(UserConfig.get("mine").miningOreCards)
		for key , cb in pairs(checkboxes) do
			imgui.setChecked(cb , saved[key] == true)
		end
	end

	return panel
end

--- @param keys string[]|nil
--- @return string[]
function MiningConfigPanel.normalizeKeys(keys)
	return keysFromSet(setFromKeys(keys))
end

return MiningConfigPanel
