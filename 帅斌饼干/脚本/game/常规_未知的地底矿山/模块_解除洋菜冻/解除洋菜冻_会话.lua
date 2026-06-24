--[[
模块: 解除洋菜冻会话
路径: game.常规_未知的地底矿山.模块_解除洋菜冻.解除洋菜冻_会话
功能: 解除洋菜冻完成/无操作后的冷却等待持久化
依赖: lib.store, lib.logger, lib.user-config
--]]

local Store = require("lib.store")
local Logger = require("lib.logger")
local UserConfig = require("lib.user-config")

local Session = {}
local KEY = "mine_jelly_session"
local TAG = "[解除洋菜冻.会话]"
local DEFAULT_WAIT_SEC = 3600

local function resolveWaitSec(customSec)
    if type(customSec) == "number" and customSec > 0 then
        return math.floor(customSec)
    end
    local cfg = UserConfig.get("mine")
    local sec = cfg and cfg.jellyIntervalSec
    if type(sec) == "number" and sec > 0 then
        return math.floor(sec)
    end
    return DEFAULT_WAIT_SEC
end

local function loadRaw()
    local raw = Store.get(KEY)
    if type(raw) ~= "table" then
        return nil
    end
    return raw
end

--- 记录等待截止时间
--- @param waitSec number|nil 默认读 UserConfig.mine.jellyIntervalSec（1 小时）
function Session.enterWait(waitSec)
    waitSec = resolveWaitSec(waitSec)
    local until_ = os.time() + waitSec
    Store.set(KEY, {
        waitUntil = until_,
        recordedAt = os.time(),
    })
    Logger.info(string.format(TAG .. " enterWait: 等待 %ds（到期戳 %d）", waitSec, until_))
end

--- 检查是否可运行
--- @return boolean ok
--- @return number remainSec
function Session.checkReady()
    local raw = loadRaw()
    if not raw or not raw.waitUntil then
        return true, 0
    end
    local remain = raw.waitUntil - os.time()
    if remain <= 0 then
        Logger.debug(TAG .. " checkReady: 等待已到期，可运行")
        return true, 0
    end
    Logger.debug(string.format(TAG .. " checkReady: 等待中，剩余 %ds", remain))
    return false, remain
end

--- @return number remainSec
function Session.restoreProgress()
    local _, remain = Session.checkReady()
    return remain
end

function Session.clear()
    Store.set(KEY, {})
    Logger.info(TAG .. " clear: 会话已清理")
end

--- @return string
function Session.describe()
    local raw = loadRaw()
    if not raw or not raw.waitUntil then
        return "无等待记录"
    end
    local remain = raw.waitUntil - os.time()
    if remain > 0 then
        return string.format("冷却中，剩余 %ds", remain)
    end
    return "冷却已到期"
end

return Session
