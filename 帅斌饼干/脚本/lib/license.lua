--[[
模块: 卡密验证
路径: lib.license
功能: 百宝云绑定/试用/解绑/充卡/公告/校验/心跳
依赖: config, lib.paths, lib.http-client, lib.string-util, lib.device-id
--]]

local Config = require("config")
local Paths = require("lib.paths")
local HttpClient = require("lib.http-client")
local StringUtil = require("lib.string-util")
local DeviceId = require("lib.device-id")

local License = {}

local staticConfig = nil
local deviceId = nil
local loginState = "none"
local regCode = ""
local accessToken = ""
local remainingMinutes = -1
local lastError = ""

local heartbeatThread = nil
local heartbeatStopFlag = false

local OFFLINE_ERR = "操作失败:注册码已经下线."

local function buildUrl(queryString)
    return string.format("%s/%s?%s", staticConfig.API_HOST, staticConfig.TOKEN, queryString)
end

local function request(queryString)
    local body, err = HttpClient.get(buildUrl(queryString), 30)
    if not body then
        lastError = err or "通讯失败"
        return false, lastError
    end
    lastError = ""
    return true, body
end

local function saveSession()
    Paths.ensureDataDir()
    local payload = jsonLib.encode({
        regCode = regCode,
        accessToken = accessToken,
        loginState = loginState,
        remainingMinutes = remainingMinutes,
    })
    writeFile(Paths.getLicensePath(), payload)
end

local function loadSession()
    Paths.ensureDataDir()
    local raw = readFile(Paths.getLicensePath())
    if not raw or raw == "" then
        return
    end
    local ok, data = pcall(jsonLib.decode, raw)
    if not ok or type(data) ~= "table" then
        print("[WARN][License] license.json 解析失败")
        return
    end
    regCode = data.regCode or ""
    accessToken = data.accessToken or ""
    loginState = data.loginState or "none"
    remainingMinutes = data.remainingMinutes or -1
end

local function login(code)
    regCode = code
    local query = string.format(
        "flag=login&DeviceID=%s&RegCode=%s&ProjectName=%s",
        deviceId, code, staticConfig.PROJECT_NAME
    )
    local ok, ret = request(query)
    if not ok then
        return false, ret
    end

    local parts = StringUtil.split(ret, "|")
    if parts and #parts == 3
        and tonumber(parts[2]) ~= nil
        and tonumber(parts[3]) ~= nil then
        loginState = "registered"
        remainingMinutes = tonumber(parts[2])
        accessToken = parts[3]
        return true
    end

    lastError = ret
    return false, ret
end

local function tryLogin(code)
    code = code or ""
    local query = string.format(
        "flag=trylogin&RegCode=%s&ProjectName=%s",
        code, staticConfig.PROJECT_NAME
    )
    local ok, ret = request(query)
    if ok and ret == "成功" then
        loginState = "trial"
        regCode = code
        accessToken = ""
        return true
    end

    if ret == "操作失败:此试用模式不支持TryLogin函数(不支持普通试用模式),请使用试用登陆扩展模式." then
        query = string.format(
            "flag=tryloginex&DeviceID=%s&ProjectName=%s",
            deviceId, staticConfig.PROJECT_NAME
        )
        ok, ret = request(query)
        if ok then
            local parts = StringUtil.split(ret, "|")
            if parts and #parts == 3
                and tonumber(parts[2]) ~= nil
                and parts[3] ~= "" then
                loginState = "trial"
                accessToken = parts[2]
                regCode = parts[3]
                return true
            end
        end
    end

    lastError = ret or "试用登录失败"
    return false, lastError
end

local function relogin()
    if loginState == "trial" then
        return tryLogin(regCode)
    end
    return login(regCode)
end

local function getRemainingMinutes()
    local query
    if loginState == "registered" then
        query = string.format(
            "flag=getregcodetime&DeviceID=%s&RegCode=%s&ProjectName=%s&AccessToken=%s",
            deviceId, regCode, staticConfig.PROJECT_NAME, accessToken
        )
    elseif loginState == "trial" then
        query = string.format(
            "flag=gettrytime&DeviceID=%s&ProjectName=%s",
            deviceId, staticConfig.PROJECT_NAME
        )
    else
        lastError = "操作失败:尚未登录无法获取剩余分钟"
        return -1, lastError
    end

    local ok, ret = request(query)
    if ok and tonumber(ret) ~= nil then
        remainingMinutes = tonumber(ret)
        lastError = ""
        return remainingMinutes
    end

    lastError = ret or "获取剩余分钟失败"
    return -1, lastError
end

local function unbindRemote()
    local query = string.format(
        "flag=ubind&DeviceID=%s&RegCode=%s&ProjectName=%s&UbindPassword=%s",
        deviceId, regCode, staticConfig.PROJECT_NAME, staticConfig.UNBIND_PASSWORD
    )
    local ok, ret = request(query)
    if ok and tonumber(ret) ~= nil then
        return true
    end
    lastError = ret or "解绑失败"
    return false, lastError
end

local function invalidateSession(keepRegCode)
    loginState = "none"
    accessToken = ""
    remainingMinutes = -1
    if not keepRegCode then
        regCode = ""
    end
    saveSession()
end

local function restoreSessionOnInit()
    local minutes, errMsg = getRemainingMinutes()
    if minutes ~= -1 then
        saveSession()
        return true
    end

    errMsg = errMsg or lastError or ""
    if errMsg == OFFLINE_ERR then
        print("[License] 注册码已下线，尝试重新登录…")
        if relogin() then
            saveSession()
            print("[License] 重新登录成功")
            return true
        end
        print("[WARN][License] 重新登录失败: " .. tostring(lastError or errMsg))
        invalidateSession(true)
        return false
    end

    if string.find(errMsg, "操作失败", 1, true) then
        print("[WARN][License] 会话失效: " .. errMsg)
        invalidateSession(true)
        return false
    end

    print("[WARN][License] 会话校验失败: " .. errMsg)
    return false
end

local function clampHeartbeatInterval(seconds)
    local interval = tonumber(seconds) or 600
    if interval > 1800 then
        return 1800
    end
    if interval < 600 then
        return 600
    end
    return interval
end

local function runHeartbeat(intervalSec)
    local maxFailCount = 30
    local isFirstPing = true
    heartbeatStopFlag = false

    while not heartbeatStopFlag do
        local retryIntervalSec = math.ceil(intervalSec / 2)
        local waitUntil = os.time() + (isFirstPing and 180 or intervalSec)

        while not heartbeatStopFlag and os.time() < waitUntil do
            sleep(3000)
        end
        if heartbeatStopFlag then
            break
        end

        local attempt = 0
        while not heartbeatStopFlag and attempt < maxFailCount do
            local minutes, errMsg = getRemainingMinutes()
            if minutes ~= -1 and (errMsg == nil or errMsg == "") then
                saveSession()
                if minutes <= 0 then
                    toast("注册码已到期", 0, 0, 14)
                    print("[WARN][License] 注册码已到期，剩余分钟: " .. tostring(minutes))
                    return
                end
                isFirstPing = false
                break
            end

            errMsg = errMsg or lastError or ""
            if errMsg == OFFLINE_ERR then
                print("[License] 注册码已下线，尝试重新登录…")
                local ok = relogin()
                if ok then
                    saveSession()
                    print("[License] 重新登录成功")
                    isFirstPing = false
                    break
                end
                print("[WARN][License] 重新登录失败: " .. tostring(lastError or errMsg))
            elseif string.find(errMsg, "操作失败", 1, true) then
                toast(errMsg, 0, 0, 14)
                print("[WARN][License] 心跳停止: " .. errMsg)
                return
            end

            attempt = attempt + 1
            if attempt >= maxFailCount then
                toast(errMsg, 0, 0, 14)
                print("[WARN][License] 心跳停止: " .. errMsg)
                return
            end

            for _ = 1, retryIntervalSec do
                if heartbeatStopFlag then
                    return
                end
                sleep(1000)
            end
            retryIntervalSec = math.max(60, math.ceil(retryIntervalSec / 2))
        end
    end
end

--- 初始化：加载本地会话，已登录则刷新剩余时间并启动心跳
function License.init()
    staticConfig = Config.licenseStatic()
    deviceId = DeviceId.getDeviceCode()
    loadSession()

    if (loginState == "registered" and regCode ~= "") or loginState == "trial" then
        if restoreSessionOnInit() then
            License.startHeartbeat()
        end
    end
end

--- 绑定注册码
--- @param code string
--- @return boolean ok
--- @return string|nil err
function License.bind(code)
    code = StringUtil.trim(code)
    if code == "" then
        return false, "请输入注册码"
    end

    local ok, err = login(code)
    if not ok then
        return false, err
    end

    saveSession()
    License.startHeartbeat()
    print("[License] 注册码绑定成功")
    return true
end

--- 试用登录
--- @param code string|nil
--- @return boolean ok
--- @return string|nil err
function License.tryBind(code)
    local ok, err = tryLogin(StringUtil.trim(code or ""))
    if not ok then
        return false, err
    end

    saveSession()
    License.startHeartbeat()
    print("[License] 试用登录成功")
    return true
end

--- 解绑注册码
--- @return boolean ok
--- @return string|nil err
function License.unbind()
    License.stopHeartbeat()
    if loginState == "none" then
        regCode = ""
        accessToken = ""
        remainingMinutes = -1
        saveSession()
        return true
    end

    local ok, err = true, nil
    if loginState == "registered" then
        ok, err = unbindRemote()
    end
    loginState = "none"
    regCode = ""
    accessToken = ""
    remainingMinutes = -1
    saveSession()
    if ok then
        print("[License] 解绑成功")
    end
    return ok, err
end

--- 启动前校验
--- @return boolean ok
--- @return string|nil err
function License.verify()
    if loginState ~= "registered" and loginState ~= "trial" then
        return false, "请先绑定注册码"
    end
    if remainingMinutes <= 0 then
        return false, "注册码已过期"
    end
    return true
end

--- 刷新剩余分钟
--- @return number minutes
function License.refreshRemainingMinutes()
    local minutes = getRemainingMinutes()
    if minutes ~= -1 then
        saveSession()
    end
    return minutes
end

--- 获取项目公告
--- @return string|nil placard
--- @return string|nil err
function License.getPlacard()
    local query = "flag=getplacard&ProjectName=" .. staticConfig.PROJECT_NAME
    local ok, ret = request(query)
    if ok then
        if ret == "" then
            return nil, "操作失败:项目公告为空"
        end
        return ret
    end
    return nil, ret
end

--- 以卡充卡
--- @param newCode string
--- @param oldCode string|nil 默认当前卡
--- @return boolean ok
--- @return string|nil err
function License.chargeCard(newCode, oldCode)
    newCode = StringUtil.trim(newCode or "")
    oldCode = StringUtil.trim(oldCode or regCode)
    if newCode == "" then
        return false, "请输入新卡"
    end
    if oldCode == "" then
        return false, "当前无可用旧卡"
    end

    local query = string.format(
        "flag=charge&NewRegCode=%s&OldRegCode=%s",
        newCode, oldCode
    )
    local ok, ret = request(query)
    if ok and ret == "OK" then
        License.refreshRemainingMinutes()
        print("[License] 以卡充卡成功")
        return true
    end
    lastError = ret or "以卡充卡失败"
    return false, lastError
end

--- 启动心跳
function License.startHeartbeat()
    License.stopHeartbeat()
    heartbeatStopFlag = false
    local interval = clampHeartbeatInterval(staticConfig.HEARTBEAT_INTERVAL)
    heartbeatThread = beginThread(function()
        runHeartbeat(interval)
    end)
end

--- 停止心跳
function License.stopHeartbeat()
    heartbeatStopFlag = true
    if heartbeatThread then
        heartbeatThread:stopThread()
        heartbeatThread = nil
    end
end

--- 获取授权状态
--- @return table status
function License.getStatus()
    return {
        state = loginState,
        remainingMinutes = remainingMinutes,
        accessToken = accessToken,
        regCode = regCode,
        message = lastError,
    }
end

return License
