--[[
模块: 解除洋菜冻页面
路径: game.常规_未知的地底矿山.模块_解除洋菜冻.解除洋菜冻_页面
功能: 解除洋菜冻页面识别、按钮点击、OCR 查找配置按钮
依赖: lib.color, lib.touch, lib.ocr, lib.logger, game.常规_未知的地底矿山.矿山_特征库
--]]

local Color = require("lib.color")
local Touch = require("lib.touch")
local Ocr = require("lib.ocr")
local Logger = require("lib.logger")

local MineFeatureLib = require("game.常规_未知的地底矿山.矿山_特征库")

local JellyPage = {}
local TAG = "[解除洋菜冻.页面]"

local mineHomeFeatures = MineFeatureLib.mineHome()
local jellyFeatures = MineFeatureLib.jelly()
local configJellyFeatures = jellyFeatures.配置洋菜冻

-- ==================== 解除洋菜冻主页面 ====================

function JellyPage.isJellyPage()
    return Color.match(jellyFeatures.feature)
end

function JellyPage.waitJellyPage(timeoutMs, intervalMs)
    return Color.waitMatch(jellyFeatures.feature, timeoutMs or 30000, intervalMs or 500, 800)
end

function JellyPage.canClaimAll()
    return Color.match(jellyFeatures.可全部领取_特征)
end

function JellyPage.tapClaimAll()
    Touch.tapArea(jellyFeatures.全部领取_按钮, 800)
end

function JellyPage.tapSettle()
    Touch.tapArea(jellyFeatures.settleBtn, 800)
end

function JellyPage.tapBack()
    Touch.tapArea(jellyFeatures.backBtn, 1000)
end

--- OCR 查找「配置」按钮坐标
--- @return table|nil point {x, y}
function JellyPage.findConfigBtn()
    local x, y = Ocr.find("配置", jellyFeatures.OCR识别区域)
    if x and y then
        return { x = x, y = y }
    end
    return nil
end

function JellyPage.tapConfigBtn(point)
    if type(point) == "table" and type(point.x) == "number" and type(point.y) == "number" then
        Touch.tapR(point.x, point.y, 800)
        return true
    end
    return false
end

--- 点击矿山相关入口的「解除洋菜冻」按钮
--- 坐标定义在矿山_特征库.mineVenture 中
function JellyPage.tapEnterBtn()
    local ventureFeatures = MineFeatureLib.mineVenture()
    Touch.tapArea(ventureFeatures.解除洋菜冻_按钮, 1000)
end

-- ==================== 配置洋菜冻界面 ====================

function JellyPage.isConfigPage()
    return Color.match(configJellyFeatures.feature)
end

function JellyPage.waitConfigPage(timeoutMs, intervalMs)
    return Color.waitMatch(configJellyFeatures.feature, timeoutMs or 30000, intervalMs or 500, 800)
end

function JellyPage.canChoose()
    return Color.match(configJellyFeatures.可选择_特征)
end

function JellyPage.tapChoose()
    Touch.tapArea(configJellyFeatures.选择_按钮, 800)
end

function JellyPage.tapConfigBack()
    Touch.tapArea(configJellyFeatures.backBtn, 1000)
end

-- ==================== 剩余时间 OCR ====================

--- 从文本中解析中文时长
--- 支持：X天Y小时Z分钟W秒 / X小时Y分钟 / Y分钟 等组合
--- @param text string
--- @return number|nil remainSec
local function parseRemainTimeText(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    local days = tonumber(text:match("(%d+)%s*天")) or 0
    local hours = tonumber(text:match("(%d+)%s*小时")) or 0
    local minutes = tonumber(text:match("(%d+)%s*分钟")) or 0
    local seconds = tonumber(text:match("(%d+)%s*秒")) or 0
    if days == 0 and hours == 0 and minutes == 0 and seconds == 0 then
        return nil
    end
    return days * 86400 + hours * 3600 + minutes * 60 + seconds
end

--- OCR 识别解除洋菜冻剩余时间
--- 在 `jellyFeatures.OCR识别区域` 内扫描，提取时间文本并转为秒数
--- @return number|nil remainSec 剩余秒数，识别失败返回 nil
function JellyPage.readRemainTime()
    local r = Ocr.scan(jellyFeatures.OCR识别区域)
    if not r then
        Logger.warn(TAG .. " readRemainTime: OCR 扫描失败")
        return nil
    end

    -- 优先从合并 text 解析
    local remainSec = parseRemainTimeText(r.text or "")
    if remainSec then
        Logger.info(TAG .. " readRemainTime: 识别到剩余时间 " .. remainSec .. "s")
        return remainSec
    end

    -- 兜底：逐 item 解析
    for _, item in ipairs(r.items or {}) do
        remainSec = parseRemainTimeText(item.words or "")
        if remainSec then
            Logger.info(TAG .. " readRemainTime: 从 item 识别到剩余时间 " .. remainSec .. "s")
            return remainSec
        end
    end

    Logger.warn(TAG .. " readRemainTime: 未识别到剩余时间，raw=" .. tostring(r.text))
    return nil
end

return JellyPage
