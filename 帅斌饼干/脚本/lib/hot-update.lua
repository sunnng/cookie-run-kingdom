--[[
模块: 热更新
路径: lib.hot-update
功能: 版本检测、下载安装、启动时热更流程
依赖: jsonLib, httpGet, downloadFile, installLrPkg, config, ui.hot-update-dialog
--]]

local Config = require("config")
local HotUpdateDialog = require("ui.hot-update-dialog")

local HotUpdate = {}

local MD5_RETRIES = 3

local function decodeJson(str)
    if not str or str == "" then
        return nil
    end
    local ok, t = pcall(jsonLib.decode, str)
    if ok and type(t) == "table" then
        return t
    end
    return nil
end

local function joinUrl(baseUrl, fileName)
    return (baseUrl or ""):gsub("/+$", "") .. "/" .. encodeUrl(tostring(fileName))
end

local function ensureDir(dir)
    return dir and dir ~= "" and (fileExist(dir) or mkdir(dir) == true)
end

local function notify(onProgress, percent, stage)
    if onProgress then
        onProgress(percent, stage)
    end
end

local function downloadPackage(packageUrl, savePath, options)
    options = options or {}
    local verifyMd5 = options.verifyMd5 == true
    local expectedMd5 = tostring(options.expectedMd5 or "")
    local onProgress = options.onProgress

    local saveDir = savePath:match("^(.*)/[^/]+$")
    if saveDir and not ensureDir(saveDir) then
        return false, "下载目录创建失败"
    end

    local retriesLeft = verifyMd5 and MD5_RETRIES or 1
    while retriesLeft > 0 do
        notify(onProgress, 0, "downloading")
        local code = downloadFile(packageUrl, savePath, function(pos)
            notify(onProgress, pos, "downloading")
        end)
        if code ~= 0 then
            print("[ERROR][HotUpdate] 下载失败: " .. tostring(code))
            return false, "下载失败"
        end

        if not verifyMd5 then
            notify(onProgress, 100, "downloading")
            return true
        end

        notify(onProgress, 100, "verifying")
        retriesLeft = retriesLeft - 1
        local actualMd5 = tostring(fileMD5(savePath) or "")
        if expectedMd5 ~= "" and actualMd5 == expectedMd5 then
            return true
        end

        delfile(savePath)
        if retriesLeft <= 0 then
            print("[ERROR][HotUpdate] MD5 校验失败: " .. actualMd5)
            return false, "MD5 校验失败"
        end
        print("[WARN][HotUpdate] MD5 不匹配，重试下载")
    end

    return false, "下载失败"
end

local function installPackage(packagePath, onProgress)
    if not packagePath or not fileExist(packagePath) then
        return false
    end
    notify(onProgress, 100, "installing")
    installLrPkg(packagePath)
    sleep(3000)
    delfile(packagePath)
    print("[INFO][HotUpdate] 已安装: " .. packagePath)
    return true
end

--- 拉取远端信息文件并比对本地版本
--- @param baseUrl string 直链根目录
--- @param infoFile string 信息文件名
--- @param localVersion string|number 当前脚本版本
--- @param timeoutSec number|nil 默认 30
--- @return table { ok, hasUpdate, message, remoteVersion, remoteMd5 }
function HotUpdate.check(baseUrl, infoFile, localVersion, timeoutSec)
    local result = {
        ok = false,
        hasUpdate = false,
        message = "",
        remoteVersion = "",
        remoteMd5 = "",
    }

    if not baseUrl or baseUrl == "" then
        result.message = "未配置热更地址"
        return result
    end

    local body, statusCode = httpGet(joinUrl(baseUrl, infoFile), timeoutSec or 30)
    if statusCode ~= 200 then
        result.message = "更新访问异常，请联系作者"
        print("[WARN][HotUpdate] 信息文件请求失败: " .. tostring(statusCode))
        return result
    end

    local info = decodeJson(body)
    if not info then
        result.message = "更新信息解析失败"
        print("[WARN][HotUpdate] 信息文件 JSON 无效")
        return result
    end

    result.ok = true
    result.remoteVersion = tostring(info.version or "")
    result.remoteMd5 = tostring(info.MD5 or info.md5 or "")
    result.message = tostring(info.msg or info.message or "发现新版本")
    result.hasUpdate = result.remoteVersion ~= tostring(localVersion)
    if not result.hasUpdate then
        result.message = "未检测到热更"
    end
    return result
end

--- 下载、校验并安装更新包
--- @param options table { baseUrl, packageFile, remoteMd5, verifyMd5, downloadDir, onProgress }
--- @return boolean ok
--- @return string|nil err
function HotUpdate.apply(options)
    options = options or {}
    local baseUrl = options.baseUrl
    local packageFile = options.packageFile
    local downloadDir = (options.downloadDir or "/sdcard/Download/"):gsub("/+$", "")

    if not baseUrl or baseUrl == "" or not packageFile or packageFile == "" then
        return false, "热更参数不完整"
    end
    if not ensureDir(downloadDir) then
        return false, "下载目录不可用"
    end

    local savePath = downloadDir .. "/" .. packageFile
    local ok, err = downloadPackage(joinUrl(baseUrl, packageFile), savePath, {
        verifyMd5 = options.verifyMd5 == true,
        expectedMd5 = options.remoteMd5,
        onProgress = options.onProgress,
    })
    if not ok then
        return false, err
    end
    if not installPackage(savePath, options.onProgress) then
        return false, "安装失败"
    end
    return true
end

--- 启动时检测并处理热更（主界面之前调用）
function HotUpdate.runOnStartup()
    local c = Config.hotUpdateStatic()
    if c.ENABLED ~= true then
        return false
    end
    if not c.BASE_URL or c.BASE_URL == "" then
        print("[WARN][HotUpdate] 热更已启用但未配置 BASE_URL")
        return false
    end

    local checkResult = HotUpdate.check(c.BASE_URL, c.INFO_FILE, c.VERSION, c.TIMEOUT_SEC)
    if not checkResult.ok then
        print("[WARN][HotUpdate] " .. checkResult.message)
        if c.TOAST_ON_ERROR then
            toast(checkResult.message, 0, 0, 14)
        end
        return false
    end
    if not checkResult.hasUpdate then
        print("[HotUpdate] " .. checkResult.message)
        return false
    end

    print("[HotUpdate] 发现热更: " .. checkResult.remoteVersion)
    HotUpdateDialog.show({
        content = checkResult.message,
        remoteVersion = checkResult.remoteVersion,
        localVersion = c.VERSION,
        countdownSec = c.COUNTDOWN_SEC,
        slogan = c.SLOGAN,
        onApply = function(onProgress)
            local ok, err = HotUpdate.apply({
                baseUrl = c.BASE_URL,
                packageFile = c.PACKAGE_FILE,
                remoteMd5 = checkResult.remoteMd5,
                verifyMd5 = c.VERIFY_MD5,
                downloadDir = c.DOWNLOAD_DIR,
                onProgress = onProgress,
            })
            if not ok then
                local errMsg = "热更失败: " .. tostring(err)
                print("[WARN][HotUpdate] " .. errMsg)
                toast(errMsg, 0, 0, 14)
            else
                print("[HotUpdate] 热更安装完成")
            end
            return ok, err
        end,
    })
    return true
end

return HotUpdate
