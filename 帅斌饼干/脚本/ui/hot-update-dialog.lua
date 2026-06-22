--[[
模块: 热更新界面
路径: ui.hot-update-dialog
功能: imgui 公告 + 进度（单窗口两阶段）
依赖: ui.components, imgui, beginThread
--]]

local Components = require("ui.components")

local HotUpdateDialog = {}

local STAGE_TEXT = {
    downloading = "正在下载更新包…",
    verifying = "正在校验文件完整性…",
    installing = "正在安装，脚本即将重启…",
    failed = "更新失败",
}

local function setGroupVisible(widgets, visible)
    for _, handle in ipairs(widgets) do
        imgui.setWidgetVisible(handle, visible)
    end
end

local function onUiThread(fn)
    if type(imgui.post) == "function" then
        imgui.post(fn)
    else
        fn()
    end
end

--- 公告倒计时 → 确认后同窗口展示进度并执行 onApply
--- @param options table { content, remoteVersion, localVersion, countdownSec, slogan, onApply }
function HotUpdateDialog.show(options)
    options = options or {}
    local countdownSec = options.countdownSec or 3
    local onApply = options.onApply

    if not imgui.isSupport() then
        for sec = countdownSec, 1, -1 do
            toast("即将更新（" .. sec .. "s）", 0, 0, 14)
            sleep(1000)
        end
        if onApply then
            onApply(function() end)
        end
        return
    end

    local started = false
    local updating = false
    local remaining = countdownSec

    local windowHandle = Components.createWindow("软件更新", 560, 350, false)
    local rootLayout = imgui.createVerticalLayout(windowHandle, 0, 0)
    imgui.setWidgetStyle(rootLayout, ImGuiStyleVar.ItemSpacing, 0, 10)

    local announceWidgets = {}
    local function addAnnounce(widget)
        announceWidgets[#announceWidgets + 1] = widget
        return widget
    end

    local slogan = options.slogan or "帅斌饼干"
    addAnnounce(imgui.createLabel(rootLayout, slogan, true))
    addAnnounce(imgui.createLabel(
        rootLayout,
        "当前 v" .. tostring(options.localVersion or "") .. "  ->  新版本 v" .. tostring(options.remoteVersion or ""),
        true
    ))
    addAnnounce(imgui.createLabel(rootLayout, "[更新内容]", true))
    addAnnounce(imgui.createLabel(rootLayout, options.content or "", false))
    local countdownLabel = addAnnounce(imgui.createLabel(rootLayout, "", false))
    local updateButton = addAnnounce(imgui.createButton(rootLayout, "立即更新", -1, 52))

    local progressWidgets = {}
    local function addProgress(widget)
        imgui.setWidgetVisible(widget, false)
        progressWidgets[#progressWidgets + 1] = widget
        return widget
    end

    addProgress(imgui.createLabel(rootLayout, slogan .. " · 正在更新", true))
    local statusLabel = addProgress(imgui.createLabel(rootLayout, STAGE_TEXT.downloading, true))
    local progressBar = addProgress(imgui.createProgressBar(rootLayout, 0, -1, 40))

    local function setProgress(percent, stage, statusOverride)
        local text = statusOverride or STAGE_TEXT[stage] or STAGE_TEXT.downloading
        imgui.setWidgetText(statusLabel, text)
        imgui.setProgressBarPos(progressBar, math.max(0, math.min(100, percent)) / 100)
    end

    local function refreshCountdown()
        imgui.setWidgetText(countdownLabel, "点击按钮立即更新，或等待 " .. remaining .. " 秒自动更新")
        imgui.setWidgetText(updateButton, "立即更新（" .. remaining .. "s）")
    end

    local function beginUpdate()
        if started then
            return
        end
        started = true
        updating = true
        setGroupVisible(announceWidgets, false)
        setGroupVisible(progressWidgets, true)
        onUiThread(function()
            setProgress(0, "downloading")
        end)

        beginThread(function()
            local ok, err = true, nil
            if onApply then
                ok, err = onApply(function(percent, stage)
                    onUiThread(function()
                        setProgress(percent, stage)
                    end)
                end)
            end

            if not ok then
                local errText = STAGE_TEXT.failed
                if err and err ~= "" then
                    errText = errText .. "：" .. tostring(err)
                end
                onUiThread(function()
                    setProgress(0, "failed", errText)
                end)
                sleep(2500)
            end

            updating = false
            onUiThread(function()
                if type(imgui.close) == "function" then
                    imgui.close()
                end
            end)
        end)
    end

    imgui.setOnClick(updateButton, beginUpdate)

    local function tickCountdown()
        setTimer(function()
            if started then
                return
            end
            remaining = remaining - 1
            if remaining <= 0 then
                beginUpdate()
                return
            end
            refreshCountdown()
            tickCountdown()
        end, 1000)
    end

    refreshCountdown()
    tickCountdown()

    imgui.setOnClose(windowHandle, function(handle)
        if updating then
            return false
        end
        if imgui.isWindowValid and imgui.isWindowValid(handle) then
            imgui.destroyWindow(handle)
        else
            pcall(imgui.destroyWindow, handle)
        end
        if type(imgui.close) == "function" then
            imgui.close()
        end
    end)

    if imgui.show(true) ~= true then
        print("热更界面显示失败:", imgui.getLastError())
    end
end

return HotUpdateDialog
