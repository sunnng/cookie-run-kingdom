--[[
模块: 远程控制
路径: lib.remote-control
功能: 网页远程操控模拟器入口(start/stop)
依赖: lib.remote-control.ws-client / frame-pusher / cmd-executor / encoder
--]]

local Logger = require("lib.logger")
local WsClient = require("lib.remote-control.ws-client")
local FramePusher = require("lib.remote-control.frame-pusher")

local RemoteControl = {}

local wsThread = nil
local frameThread = nil
local started = false

--- 启动远程控制(创建两个工作线程)
--- @param block boolean|nil 是否阻塞主线程；独立运行时传 true
function RemoteControl.start(block)
    if started then
        Logger.warn("[rc] 远程控制已启动")
        return
    end
    started = true
    Logger.info("[rc] 启动远程控制")

    -- 线程 A: WebSocket 连接+心跳+重连
    wsThread = beginThread(function()
        WsClient.start()
    end)

    -- 线程 B: 画面推送
    frameThread = beginThread(function()
        -- 稍作等待,让 WS 先连上
        sleep(500)
        FramePusher.loop()
    end)

    -- 若作为独立脚本运行,阻塞主线程防止脚本退出
    if block then
        while started do
            sleep(1000)
        end
    end
end

--- 停止远程控制
function RemoteControl.stop()
    if not started then
        return
    end
    started = false
    Logger.info("[rc] 停止远程控制")

    FramePusher.stop()
    WsClient.stop()

    -- 等待线程结束(若平台支持 waitThread)
    if frameThread then
        pcall(waitThread, frameThread, 2000)
        frameThread = nil
    end
    if wsThread then
        pcall(waitThread, wsThread, 2000)
        wsThread = nil
    end
end

return RemoteControl
