--[[
模块: 远程控制 - 画面编码器
路径: lib.remote-control.encoder
功能: cv.snapShot → JPEG → base64(纯内存或临时文件降级)
--]]

local Logger = require("lib.logger")
local Config = require("config")

local Encoder = {}

local TMP_JPG = "/sdcard/.remote-control-frame.jpg"

--- 获取缩放后的尺寸
local function scaledSize(srcW, srcH, maxW)
    if srcW <= maxW then
        return srcW, srcH
    end
    local ratio = maxW / srcW
    return math.floor(srcW * ratio), math.floor(srcH * ratio)
end

--- 尝试用 cv.imencode 编码为 JPEG
local function encodeWithImencode(mat, quality)
    if not cv.imencode then
        return nil
    end
    -- OpenCV 常量兼容: IMWRITE_JPEG_QUALITY = 1
    local ok, buf = pcall(function()
        local q = tonumber(quality) or 60
        return cv.imencode(".jpg", mat, { cv.IMWRITE_JPEG_QUALITY or 1, q })
    end)
    if ok and buf and type(buf) == "string" and #buf > 0 then
        return buf
    end
    return nil
end

--- 降级: cv.imwrite 临时文件 + getFileBase64
local function encodeWithImwrite(mat)
    local ok = pcall(function() return cv.imwrite(TMP_JPG, mat) end)
    if not ok then
        return nil
    end
    if not fileExist(TMP_JPG) then
        return nil
    end
    local b64 = getFileBase64(TMP_JPG)
    delfile(TMP_JPG)
    return b64
end

--- 截图并编码为 base64 JPEG
--- @return string|nil base64
--- @return number|nil w
--- @return number|nil h
function Encoder.captureAndEncode()
    local cfg = Config.remoteControlStatic()
    local maxW = cfg.SCALE_MAX_WIDTH or 720
    local quality = cfg.JPEG_QUALITY or 60

    local srcW, srcH = getDisplaySize()
    if not srcW or not srcH then
        Logger.error("[rc.encoder] 无法获取屏幕尺寸")
        return nil
    end

    local mat = cv.snapShot(0, 0, srcW, srcH)
    if not mat then
        Logger.error("[rc.encoder] cv.snapShot 失败")
        return nil
    end

    local dstW, dstH = scaledSize(srcW, srcH, maxW)
    local needResize = dstW ~= srcW

    if needResize then
        local scaled = cv.Mat.new()
        -- OpenCV 插值兼容: INTER_LINEAR = 1
        cv.resize(mat, scaled, cv.Size(dstW, dstH), 0, 0, cv.INTER_LINEAR or 1)
        mat:release()
        mat = scaled
    end

    local b64
    local buf = encodeWithImencode(mat, quality)
    if buf then
        b64 = encodeBase64(buf)
    else
        Logger.debug("[rc.encoder] cv.imencode 不可用，使用 cv.imwrite 降级")
        b64 = encodeWithImwrite(mat)
    end

    mat:release()

    if not b64 or b64 == "" then
        Logger.error("[rc.encoder] JPEG 编码失败")
        return nil
    end

    return b64, dstW, dstH
end

return Encoder
