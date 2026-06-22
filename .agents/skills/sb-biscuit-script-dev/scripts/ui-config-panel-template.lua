--[[
模块: 配置面板模板
路径: ui.xxx-config-panel
功能: 某功能模块的专属参数配置 UI
依赖: ui.components, lib.user-config
说明: build 返回 { save = fn, refresh = fn }，由 config-tab.lua 调用
--]]

local Components = require("ui.components")
local UserConfig = require("lib.user-config")

local Panel = {}

function Panel.build(parent)
    -- TODO: 替换为实际配置 section
    local cfg = UserConfig.get("xxx")

    Components.textLabel(parent, "—— 参数配置 ——", 0, 0)

    -- 示例：数字输入框
    local valueInput = Components.labeledInput(parent, "参数名:", cfg.someValue or 0)

    -- 示例：开关
    local check = imgui.createCheckBox(parent, "启用功能", cfg.enabled == true)
    imgui.setChecked(check, cfg.enabled == true)

    local function save()
        local partial = {}

        local value = tonumber(imgui.getInputText(valueInput))
        if value and value > 0 then
            partial.someValue = math.floor(value)
        end

        partial.enabled = imgui.isChecked(check)

        UserConfig.set("xxx", partial)
    end

    local function refresh()
        local saved = UserConfig.get("xxx")
        imgui.setInputText(valueInput, tostring(saved.someValue or 0))
        imgui.setChecked(check, saved.enabled == true)
    end

    return {
        save = save,
        refresh = refresh,
    }
end

return Panel
