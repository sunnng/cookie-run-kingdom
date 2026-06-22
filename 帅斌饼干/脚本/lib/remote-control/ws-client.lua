--[[
模块: 远程控制 - WebSocket 客户端
路径: lib.remote-control.ws-client
功能: 连接中转服务器、心跳、重连、收发消息
--]]

local Logger = require("lib.logger")
local Config = require("config")
local DeviceId = require("lib.device-id")
local Executor = require("lib.remote-control.cmd-executor")

local WsClient = {}

local wsHandle = nil
local wsUrl = nil
local reconnectTimer = nil
local heartbeatTimer = nil
local running = false

--- 发送 JSON 消息
local function sendJson(obj)
    if not wsHandle then
        return false
    end
    local ok, text = pcall(jsonLib.encode, obj)
    if not ok then
        Logger.error("[rc.ws] JSON 编码失败")
        return false
    end
    return sendWebSocket(wsHandle, text)
end

--- 注册设备信息
local function doRegister()
    local w, h = getDisplaySize()
    sendJson({
        type = "register",
        id = DeviceId.getDeviceCode(),
        brand = getBrand() or "unknown",
        model = getModel() or "unknown",
        width = w or 0,
        height = h or 0,
    })
end

--- 连接服务器
function WsClient.connect()
    if wsHandle then
        return
    end
    local cfg = Config.remoteControlStatic()
    wsUrl = cfg.WS_URL
    if not wsUrl or wsUrl == "" then
        Logger.error("[rc.ws] WS_URL 未配置")
        return
    end

    Logger.info("[rc.ws] 连接 " .. wsUrl)
    wsHandle = startWebSocket(wsUrl,
        function(handle)
            Logger.info("[rc.ws] 已连接")
            doRegister()
            -- 启动心跳(旧心跳若存在则尝试停止)
            if heartbeatTimer then
                pcall(stopTimer, heartbeatTimer)
            end
            heartbeatTimer = setTimer(function()
                if running and wsHandle then
                    sendWebSocket(handle, "ping")
                end
            end, 30000)
        end,
        function(handle)
            Logger.warn("[rc.ws] 连接断开")
            wsHandle = nil
            WsClient.scheduleReconnect()
        end,
        function(handle)
            Logger.warn("[rc.ws] 连接错误")
            wsHandle = nil
            WsClient.scheduleReconnect()
        end,
        function(handle, message)
            if message == "pong" or message == "ping" then
                return
            end
            local ok, msg = pcall(jsonLib.decode, message)
            if not ok or type(msg) ~= "table" then
                Logger.warn("[rc.ws] 非法消息: " .. tostring(message))
                return
            end
            if msg.type == "cmd" then
                Executor.run(msg)
            end
        end
    )
end

--- 安排重连(setTimer 切回主线程)
function WsClient.scheduleReconnect()
    if not running then
        return
    end
    if reconnectTimer then
        pcall(stopTimer, reconnectTimer)
    end
    reconnectTimer = setTimer(function()
        reconnectTimer = nil
        if running then
            WsClient.connect()
        end
    end, 5000)
end

--- 关闭连接
function WsClient.disconnect()
    running = false
    if heartbeatTimer then
        pcall(stopTimer, heartbeatTimer)
        heartbeatTimer = nil
    end
    if reconnectTimer then
        pcall(stopTimer, reconnectTimer)
        reconnectTimer = nil
    end
    if wsHandle then
        closeWebSocket(wsHandle)
        wsHandle = nil
    end
end

--- 发送画面帧
--- @param img string base64
--- @param w number
--- @param h number
function WsClient.sendFrame(img, w, h)
    if not wsHandle then
        return false
    end
    return sendJson({
        type = "frame",
        img = img,
        w = w,
        h = h,
        ts = os.time(),
    })
end

--- 启动
function WsClient.start()
    running = true
    WsClient.connect()
end

--- 停止
function WsClient.stop()
    WsClient.disconnect()
end

return WsClient
