--[[
模块: 左上角悬浮窗
路径: ui.floating-overlay
功能: 屏幕左上角单按钮控制面板（启动 / 暂停 / 关闭脚本）
依赖: imgui, config

特性:
- 固定在屏幕左上角 (0,0)
- 仅一个紧凑主控按钮（默认 120×40，可自定义）
- 按钮状态循环: 启动脚本 -> 暂停脚本 -> 继续脚本 -> 暂停脚本 -> ...
- 提供关闭入口（通过双击/长按模式或外部调用 hide）
- 非阻塞显示（imgui.show(false)），可与脚本主逻辑并行运行
--]]

local Config = require("config")

local FloatingOverlay = {}

local win = nil
local mainBtn = nil

local SCREEN_WIDTH , SCREEN_HEIGHT = Config.displaySize()

-- 窗口与按钮尺寸（默认 120×40，紧凑小巧）
local BUTTON_WIDTH = 120
local BUTTON_HEIGHT = 40
local WINDOW_WIDTH = BUTTON_WIDTH + 16
local WINDOW_HEIGHT = BUTTON_HEIGHT + 16

-- 按钮状态枚举
local STATE = {
    STOPPED = 1 ,   -- 脚本未运行
    RUNNING = 2 ,   -- 脚本运行中
    PAUSED = 3 ,    -- 脚本已暂停
}

local currentState = STATE.STOPPED

-- 用户回调
local onStart = nil
local onPause = nil
local onResume = nil
local onClose = nil

--- 获取当前状态文本
local function getStateText()
    if currentState == STATE.STOPPED then
        return "启动脚本"
    elseif currentState == STATE.RUNNING then
        return "暂停脚本"
    elseif currentState == STATE.PAUSED then
        return "继续脚本"
    end
    return "启动脚本"
end

--- 获取当前状态颜色
local function getStateColor()
    if currentState == STATE.STOPPED then
        return 0xFF4CAF50  -- 绿色：启动
    elseif currentState == STATE.RUNNING then
        return 0xFFFF9800  -- 橙色：暂停
    elseif currentState == STATE.PAUSED then
        return 0xFF2196F3  -- 蓝色：继续
    end
    return 0xFF4CAF50
end

--- 刷新按钮外观
local function refreshButton()
    if not mainBtn or not imgui.isValidHandle(mainBtn) then
        return
    end
    imgui.setWidgetText(mainBtn , getStateText())
    imgui.setWidgetColor(mainBtn , ImGuiColor.Button , getStateColor())
end

--- 处理按钮点击
local function handleClick()
    if currentState == STATE.STOPPED then
        currentState = STATE.RUNNING
        if onStart then onStart() end
    elseif currentState == STATE.RUNNING then
        currentState = STATE.PAUSED
        if onPause then onPause() end
    elseif currentState == STATE.PAUSED then
        currentState = STATE.RUNNING
        if onResume then onResume() end
    end
    refreshButton()
end

--- 创建悬浮窗
--- @param opts table|nil 可选配置
---   opts.buttonWidth number|nil 按钮宽度，默认 120
---   opts.buttonHeight number|nil 按钮高度，默认 40
---   opts.onStart function|nil 启动脚本回调
---   opts.onPause function|nil 暂停脚本回调
---   opts.onResume function|nil 继续脚本回调
---   opts.onClose function|nil 关闭脚本/悬浮窗回调
--- @return userdata|nil windowHandle
function FloatingOverlay.create(opts)
    opts = opts or {}

    -- 允许自定义按钮尺寸
    local btnW = tonumber(opts.buttonWidth) or BUTTON_WIDTH
    local btnH = tonumber(opts.buttonHeight) or BUTTON_HEIGHT
    local winW = btnW + 16
    local winH = btnH + 16

    if not imgui.isSupport() then
        print("IMGUI 不支持，无法创建悬浮窗:", imgui.getLastError())
        return nil
    end

    -- 注册回调
    onStart = opts.onStart
    onPause = opts.onPause
    onResume = opts.onResume
    onClose = opts.onClose

    -- 若已存在则先销毁
    FloatingOverlay.destroy()

    -- 重置状态
    currentState = STATE.STOPPED

    -- 在屏幕左上角创建窗口
    win = imgui.createWindow("悬浮控制" , 0 , 0 , winW , winH , false)
    if not win or win == 0 then
        print("创建悬浮窗失败:", imgui.getLastError())
        win = nil
        return nil
    end

    -- 设置悬浮窗风格：无标题栏、无背景、不可移动、不可调整大小
    imgui.setWindowFlags(win ,
        WindowFlags.NoTitleBar |
        WindowFlags.NoResize |
        WindowFlags.NoMove |
        WindowFlags.NoScrollbar |
        WindowFlags.NoScrollWithMouse |
        WindowFlags.NoCollapse |
        WindowFlags.NoSavedSettings |
        WindowFlags.NoFocusOnAppearing |
        WindowFlags.NoBringToFrontOnFocus
    )

    -- 移除窗口 padding，让按钮贴边
    imgui.setWidgetStyle(win , ImGuiStyleVar.WindowPadding , 8.0 , 8.0)
    imgui.setWidgetStyle(win , ImGuiStyleVar.WindowRounding , 8.0)

    -- 创建主控按钮
    mainBtn = imgui.createButton(win , getStateText() , btnW , btnH)
    imgui.setWidgetStyle(mainBtn , ImGuiStyleVar.FrameRounding , 8.0)
    refreshButton()

    -- 绑定点击事件
    imgui.setOnClick(mainBtn , handleClick)

    return win
end

--- 显示悬浮窗（非阻塞）
--- @return boolean
function FloatingOverlay.show()
    if not win then
        FloatingOverlay.create()
    end
    if not win then
        return false
    end
    return imgui.show(false) == true
end

--- 关闭悬浮窗
function FloatingOverlay.hide()
    if win and imgui.isWindowValid(win) then
        imgui.close()
    end
    if onClose then
        onClose()
    end
end

--- 销毁悬浮窗资源
function FloatingOverlay.destroy()
    if win and imgui.isWindowValid(win) then
        imgui.destroyWindow(win)
    end
    win = nil
    mainBtn = nil
    currentState = STATE.STOPPED
end

--- 获取当前脚本运行状态
--- @return string "stopped" | "running" | "paused"
function FloatingOverlay.getState()
    if currentState == STATE.STOPPED then
        return "stopped"
    elseif currentState == STATE.RUNNING then
        return "running"
    elseif currentState == STATE.PAUSED then
        return "paused"
    end
    return "stopped"
end

--- 设置脚本为运行状态（外部控制用）
function FloatingOverlay.setRunning()
    currentState = STATE.RUNNING
    refreshButton()
end

--- 设置脚本为暂停状态（外部控制用）
function FloatingOverlay.setPaused()
    currentState = STATE.PAUSED
    refreshButton()
end

--- 设置脚本为停止状态（外部控制用）
function FloatingOverlay.setStopped()
    currentState = STATE.STOPPED
    refreshButton()
end

--- 获取窗口句柄
--- @return userdata|nil
function FloatingOverlay.handle()
    return win
end

return FloatingOverlay
