--[[
模块: 子玩法页面模板
路径: game.常规_玩法名.模块_子玩法.子玩法_页面
功能: 图色识别、OCR 识别、点击操作
依赖: lib.color, lib.touch, lib.ocr, lib.logger
说明: 所有比色/OCR 区域定义引用自 *_特征库.lua，本文件只写识别与点击逻辑
--]]

local Color = require("lib.color")
local Touch = require("lib.touch")
local Ocr = require("lib.ocr")
local Logger = require("lib.logger")

-- TODO: 替换为实际特征库路径
local FeatureLib = require("game.常规_XXX.XXX_特征库")

local Page = {}
local TAG = "[子玩法.页面]"

local Features = FeatureLib.xxx()

local function hasFeature(feature)
    return type(feature) == "table" and feature[1] ~= nil
end

-- ============================================================================
-- 页面识别
-- ============================================================================

function Page.isXxxPage()
    return hasFeature(Features.page.feature) and Color.match(Features.page.feature)
end

function Page.waitXxxPage(timeoutMs, intervalMs)
    if not hasFeature(Features.page.feature) then
        return false
    end
    return Color.wait(Features.page.feature, timeoutMs or 60000, intervalMs or 500)
end

function Page.isXxxHome()
    -- TODO: 补充首页特征判断
    return false
end

-- ============================================================================
-- 按钮点击
-- ============================================================================

function Page.tapEnterBtn()
    if not Features.enterBtn then
        Logger.warn(TAG .. " enterBtn 未配置")
        return false
    end
    Touch.tapArea(Features.enterBtn, 800)
    return true
end

function Page.tapBackBtn()
    if not Features.backBtn then
        Logger.warn(TAG .. " backBtn 未配置")
        return false
    end
    Touch.tapArea(Features.backBtn, 1000)
    return true
end

-- ============================================================================
-- 任务元素识别
-- ============================================================================

function Page.hasCompletedTask()
    local f = Features.completedTask
    return hasFeature(f.feature) and Color.find(f.feature) ~= nil
end

function Page.tapCompletedTask()
    local f = Features.completedTask
    if not hasFeature(f.feature) then
        return false
    end
    local x, y = Color.find(f.feature)
    if not x then
        return false
    end
    Touch.tapR(x, y, 500)
    return true
end

-- ============================================================================
-- OCR 读取
-- ============================================================================

function Page.readSomeNumber()
    if not Features.someOcrRect then
        Logger.warn(TAG .. " someOcrRect 未配置")
        return nil
    end
    return Ocr.number(Features.someOcrRect)
end

-- 持续点击确认按钮直到回到目标页面
function Page.tapUntilMatchXxxPage()
    if not Features.confirmBtn or not hasFeature(Features.page.feature) then
        Logger.warn(TAG .. " confirmBtn / page.feature 未配置")
        return false
    end
    return Color.tapUntilMatch(
        Features.confirmBtn,
        Features.page.feature,
        { timeoutMs = 30000, intervalMs = 500 }
    )
end

return Page
