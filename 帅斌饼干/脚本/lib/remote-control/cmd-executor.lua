--[[
模块: 远程控制 - 指令执行器
路径: lib.remote-control.cmd-executor
功能: 将服务器下发的 JSON action 映射到触控 API
--]]

local Logger = require("lib.logger")

local Executor = {}

--- 执行单条指令
--- @param cmd table
function Executor.run(cmd)
    if type(cmd) ~= "table" then
        Logger.warn("[rc.cmd] 非法指令格式")
        return
    end

    local action = cmd.action
    if not action then
        Logger.warn("[rc.cmd] 缺少 action")
        return
    end

    Logger.info("[rc.cmd] action=" .. tostring(action)
        .. " x=" .. tostring(cmd.x)
        .. " y=" .. tostring(cmd.y)
        .. " phase=" .. tostring(cmd.phase))

    if action == "tap" then
        tap(tonumber(cmd.x) or 0, tonumber(cmd.y) or 0)

    elseif action == "longpress" then
        local x, y = tonumber(cmd.x) or 0, tonumber(cmd.y) or 0
        local dur = tonumber(cmd.dur) or 800
        longTap(x, y)
        sleep(dur)

    elseif action == "swipe" then
        local x1, y1 = tonumber(cmd.x1) or 0, tonumber(cmd.y1) or 0
        local x2, y2 = tonumber(cmd.x2) or 0, tonumber(cmd.y2) or 0
        local time = tonumber(cmd.time) or 500
        swipe(x1, y1, x2, y2, time)

    elseif action == "touch" then
        local phase = cmd.phase
        local id = tonumber(cmd.id) or 1
        local x, y = tonumber(cmd.x) or 0, tonumber(cmd.y) or 0
        if phase == "down" then
            touchDown(id, x, y)
        elseif phase == "move" then
            touchMove(id, x, y)
        elseif phase == "moveEx" then
            local t = tonumber(cmd.time) or 16
            touchMoveEx(id, x, y, t)
        elseif phase == "up" then
            touchUp(id)
        end

    elseif action == "key" then
        local name = cmd.name or "home"
        keyPress(name)

    elseif action == "input" then
        local text = tostring(cmd.text or "")
        inputText(text)

    else
        Logger.warn("[rc.cmd] 未知 action: " .. tostring(action))
    end
end

return Executor
