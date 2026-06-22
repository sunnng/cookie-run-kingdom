local Components = require("ui.components")
local UserConfig = require("lib.user-config")
local MarketFeatures = require("game.常规_海滩交易所.交易所_坐标库")

local Panel = {}

local function stockKeys()
	local keys = {}
	for key , def in pairs(MarketFeatures.stock or MarketFeatures.Stock or {}) do
		if type(def) == "table" and def[1] ~= nil then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys)
	return keys
end

local function setFromKeys(keys)
	local set = {}
	if type(keys) == "table" then
		for _ , key in ipairs(keys) do
			set[key] = true
		end
	end
	return set
end

function Panel.build(parent)
	Components.textLabel(parent , "购买道具（同优先级，从左到右扫货）" , -1 , 0)
	local keys = stockKeys()
	local enabled = setFromKeys((UserConfig.get("seasideMarket") or {}).items)
	local checkboxes = {}
	for _ , key in ipairs(keys) do
		local row = imgui.createHorticalLayout(parent , -1 , 52)
		imgui.setLayoutBorderVisible(row , false)
		local cb = imgui.createCheckBox(row , key)
		imgui.setChecked(cb , enabled[key] == true)
		checkboxes[key] = cb
	end
	local panel = {
		keys = keys ,
		checkboxes = checkboxes ,
	}

	function panel.save()
		local items = {}
		for _ , key in ipairs(keys) do
			local cb = checkboxes[key]
			if cb and imgui.isChecked(cb) then
				items[#items + 1] = key
			end
		end
		UserConfig.set("seasideMarket" , {items = items})
		return items
	end

	function panel.refresh()
		local saved = setFromKeys((UserConfig.get("seasideMarket") or {}).items)
		for key , cb in pairs(checkboxes) do
			imgui.setChecked(cb , saved[key] == true)
		end
	end

	return panel
end

return Panel
