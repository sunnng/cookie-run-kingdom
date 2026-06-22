--[[
模块: 子玩法任务模板
路径: game.常规_玩法名.模块_子玩法.子玩法_任务
功能: 状态机驱动的任务主流程
依赖: core.state-machine, core.guard, lib.logger, lib.user-config, lib.status-hud
说明: 复制到目标路径后，替换所有 XXX/子玩法 占位符，补充 detect/navigate/业务状态
--]]

local Logger = require("lib.logger")
local StateMachine = require("core.state-machine")
local Guard = require("core.guard")
local UserConfig = require("lib.user-config")
local StatusHud = require("lib.status-hud")

-- TODO: 替换为实际模块路径
local Route = require("game.常规_XXX.XXX_路由")
local Page = require("game.常规_XXX.模块_子玩法.子玩法_页面")
local Session = require("game.常规_XXX.模块_子玩法.子玩法_会话")
local KingdomPage = require("game.通用_王国.页面")

local Task = {}
local TAG = "[子玩法]"

local function updateHud(sm, patch)
    local opts = {
        state = sm:getState(),
        extra = nil,
    }
    if patch then
        for k, v in pairs(patch) do
            opts[k] = v
        end
    end
    -- TODO: 根据需要在 status-hud.lua 增加对应 setXxx 方法
    -- StatusHud.setXxx(opts)
end

-- 识别当前页面，决定进入哪个状态
local function detect(sm)
    -- TODO: 补充页面识别分支
    if Page.isXxxPage() then
        return "xxxPage"
    elseif Page.isXxxHome() then
        return "precheck"
    elseif KingdomPage.isKingdomHome() then
        return "navigate"
    end

    Logger.warn(TAG .. " [detect] 页面识别失败")
    return false, "子玩法[detect] 页面识别失败"
end

-- 从王国首页导航到玩法首页
local function navigate(sm)
    updateHud(sm, { extra = "王国→玩法首页" })
    if Route.kingdomHomeToXxxHome() then
        return "precheck"
    end

    Logger.warn(TAG .. " [navigate] 导航失败")
    return false, "子玩法[navigate] 导航失败"
end

-- 首页预检：处理入口页的已完成任务/进入按钮等
local function precheck(sm)
    updateHud(sm, { extra = "首页预检…" })

    -- TODO: 根据业务补充预检逻辑
    Page.tapEnterBtn()
    if Page.waitXxxPage(10000, 500) then
        return "xxxPage"
    end

    Logger.warn(TAG .. " [precheck] 进入玩法页失败")
    return StateMachine.RETRY
end

-- 主要业务状态
local function xxxPage(sm)
    updateHud(sm, { extra = "执行业务…" })

    -- TODO: 补充业务逻辑
    -- 示例：识别到完成状态则领奖
    if Page.hasCompletedTask() then
        Page.tapCompletedTask()
        return "claimRewards"
    end

    -- 示例：没有可操作项则结束
    Logger.info(TAG .. " [xxxPage] 当前无可操作项")
    return "done"
end

-- 领奖/确认弹窗处理
local function claimRewards(sm)
    updateHud(sm, { extra = "领取奖励…" })

    -- TODO: 补充领奖逻辑
    if Page.tapUntilMatchXxxPage() then
        return "xxxPage"
    end

    Logger.warn(TAG .. " [claimRewards] 领奖失败")
    return StateMachine.RETRY
end

-- 结束：回王国首页 + 记录 busy
local function done(sm)
    updateHud(sm, { extra = "本轮结束回城…" })

    -- TODO: 结束前复查可选
    if Page.hasCompletedTask() then
        return "claimRewards"
    end

    if not Route.returnToKingdom() then
        Logger.warn(TAG .. " [done] 回王国首页失败")
        return false, "子玩法[done] 回王国首页失败"
    end

    Session.enterBusyWait()
    return StateMachine.DONE
end

local handlers = {
    detect = detect,
    navigate = navigate,
    precheck = precheck,
    xxxPage = xxxPage,
    claimRewards = claimRewards,
    done = done,
}

function Task.run()
    local cfg = UserConfig.get("xxx")
    if not cfg.enabled then
        Logger.info(TAG .. " 任务未启用，跳过")
        return false
    end

    Logger.info(TAG .. " 任务启动")
    StatusHud.setTask("子玩法", "启动")

    local ctx = {
        -- TODO: 添加状态机上下文字段
    }

    local sm = StateMachine.new()
    sm:init("detect", {
        maxRetry = 3,
        timeout = 1800,
        retryIntervalMs = 1000,
    })
    sm.ctx = ctx

    local ok, err = sm:run(handlers, {
        interval = 500,
        guard = Guard.check,
        label = "子玩法",
    })

    if ok then
        Logger.info(TAG .. " 任务完成")
    else
        Logger.warn(TAG .. " 任务结束：" .. tostring(err))
    end
    return ok
end

return Task
