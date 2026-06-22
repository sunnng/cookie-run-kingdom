--[[
模块: 玩法路由模板
路径: game.常规_玩法名.玩法名_路由
功能: 页面间导航（进入 + 返回王国首页）
依赖: lib.color, lib.touch, lib.logger
说明: 路由层只负责点击导航，不识别具体任务状态
--]]

local Logger = require("lib.logger")

-- TODO: 替换为实际页面模块路径
local KingdomPage = require("game.通用_王国.页面")
local XxxHomePage = require("game.常规_XXX.XXX首页_页面")
local XxxPage = require("game.常规_XXX.模块_子玩法.子玩法_页面")

local Route = {}
local TAG = "[XXX路由]"

-- 王国首页 → 玩法首页
function Route.kingdomHomeToXxxHome()
    KingdomPage.tapEventBtn()
    KingdomPage.tapXxxBtn()
    return XxxHomePage.wait()
end

-- 玩法首页 → 子玩法页
function Route.xxxHomeToXxxPage()
    XxxHomePage.tapEnterBtn()
    return XxxPage.waitXxxPage()
end

-- 玩法首页 → 王国首页
function Route.xxxHomeToKingdom()
    XxxHomePage.tapBack()
    return KingdomPage.wait()
end

-- 任意页面 → 王国首页
function Route.returnToKingdom()
    if KingdomPage.isKingdomHome() then
        return true
    end

    if XxxPage.isXxxPage() then
        XxxPage.tapBackBtn()
        if not XxxHomePage.wait() then
            Logger.warn(TAG .. " 子玩法页返回首页超时")
        end
    end

    if XxxHomePage.isCurrent() then
        if Route.xxxHomeToKingdom() then
            Logger.info(TAG .. " 已回王国首页")
            return true
        end
        Logger.warn(TAG .. " 玩法首页返回王国超时")
        return false
    end

    if KingdomPage.isKingdomHome() then
        return true
    end

    Logger.warn(TAG .. " 回王国首页失败，当前页面未知")
    return false
end

return Route
