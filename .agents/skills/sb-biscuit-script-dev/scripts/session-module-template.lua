--[[
模块: 子玩法会话模板
路径: game.常规_玩法名.模块_子玩法.子玩法_会话
功能: 任务冷却/进度持久化
依赖: lib.store, lib.logger, lib.user-config
说明: 用于跨轮次记录 busy 截止时间、次数、刷新时间等
--]]

local Store = require("lib.store")
local Logger = require("lib.logger")
local UserConfig = require("lib.user-config")

local Session = {}
local KEY = "xxx_session"
local TAG = "[子玩法.会话]"

-- TODO: 修改默认值
local DEFAULT_BUSY_SEC = 3600

-- 读取用户配置中的等待秒数
local function resolveBusySec()
    local cfg = UserConfig.get("xxx")
    local sec = cfg and cfg.intervalSec
    if type(sec) == "number" and sec > 0 then
        return math.floor(sec)
    end
    return DEFAULT_BUSY_SEC
end

local function loadRaw()
    local raw = Store.get(KEY)
    if type(raw) ~= "table" then
        return nil
    end
    return raw
end

-- busy 剩余秒数（0 表示可运行）
function Session.restoreProgress()
    local raw = loadRaw()
    if not raw or not raw.allBusyUntil then
        return 0
    end
    local remain = raw.allBusyUntil - os.time()
    if remain > 0 then
        return remain
    end
    return 0
end

-- 进入 busy 等待
function Session.enterBusyWait(waitSec)
    waitSec = waitSec or resolveBusySec()
    local until_ = os.time() + waitSec
    Store.set(KEY, {
        allBusyUntil = until_,
        recordedAt = os.time(),
    })
    Logger.info(string.format(TAG .. " enterBusyWait: busy %ds（到期戳 %d）", waitSec, until_))
end

-- 检查是否可运行
function Session.checkReady()
    local raw = loadRaw()
    if not raw or not raw.allBusyUntil then
        return true, 0
    end
    local remain = raw.allBusyUntil - os.time()
    if remain <= 0 then
        return true, 0
    end
    return false, remain
end

-- 清理会话
function Session.clear()
    Store.set(KEY, {})
    Logger.info(TAG .. " clear: 会话已清理")
end

-- 会话状态摘要（供 UI / HUD 调试展示）
function Session.describe()
    local raw = loadRaw()
    if not raw or not raw.allBusyUntil then
        return "无记录"
    end
    local remain = raw.allBusyUntil - os.time()
    if remain > 0 then
        return string.format("冷却中，剩余 %ds", remain)
    end
    return "已到期"
end

return Session
