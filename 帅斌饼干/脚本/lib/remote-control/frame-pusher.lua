--[[
模块: 远程控制 - 画面推送线程
路径: lib.remote-control.frame-pusher
功能: 独立线程循环截图、编码、推送
--]]

local Logger = require("lib.logger")
local Config = require("config")
local Encoder = require("lib.remote-control.encoder")
local WsClient = require("lib.remote-control.ws-client")

local FramePusher = {}

local pushing = false

--- 推送循环(供 beginThread 调用)
function FramePusher.loop()
    pushing = true
    local cfg = Config.remoteControlStatic()
    local interval = math.max(33, math.floor(1000 / (cfg.FRAME_FPS or 10)))

    while pushing do
        local t0 = systemTime()
        local img, w, h = Encoder.captureAndEncode()
        if img then
            WsClient.sendFrame(img, w, h)
        end
        local elapsed = systemTime() - t0
        local sleepMs = interval - elapsed
        if sleepMs > 0 then
            sleep(sleepMs)
        end
    end
end

--- 停止推送循环
function FramePusher.stop()
    pushing = false
end

return FramePusher
