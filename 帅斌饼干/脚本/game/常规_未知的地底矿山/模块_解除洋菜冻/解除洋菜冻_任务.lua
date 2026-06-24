--[[
模块: 解除洋菜冻任务
路径: game.常规_未知的地底矿山.模块_解除洋菜冻.解除洋菜冻_任务
功能: 状态机驱动解除洋菜冻领取与配置
依赖: core.state-machine, lib.logger, core.guard, lib.user-config,
      game.常规_未知的地底矿山.矿山_路由,
      game.常规_未知的地底矿山.矿山首页_页面,
      game.通用_王国.页面,
      game.常规_未知的地底矿山.模块_解除洋菜冻.解除洋菜冻_页面,
      game.常规_未知的地底矿山.模块_解除洋菜冻.解除洋菜冻_会话
--]]

local Logger = require("lib.logger")
local StateMachine = require("core.state-machine")
local Guard = require("core.guard")
local UserConfig = require("lib.user-config")
local Color = require("lib.color")

local Route = require("game.常规_未知的地底矿山.矿山_路由")
local MineFeatureLib = require("game.常规_未知的地底矿山.矿山_特征库")
local MineHomePage = require("game.常规_未知的地底矿山.矿山首页_页面")
local KingdomPage = require("game.通用_王国.页面")
local JellyPage = require("game.常规_未知的地底矿山.模块_解除洋菜冻.解除洋菜冻_页面")
local JellySession = require("game.常规_未知的地底矿山.模块_解除洋菜冻.解除洋菜冻_会话")

local jellyFeatures = MineFeatureLib.jelly()

local JellyTask = {}
local TAG = "[解除洋菜冻]"

-- ==================== 状态处理 ====================

local function detect(sm)
    if JellyPage.isJellyPage() then
        Logger.info(TAG .. " [detect] 当前在解除洋菜冻页面")
        return "processPage"
    elseif MineHomePage.isCurrent() then
        Logger.info(TAG .. " [detect] 当前在矿山首页")
        return "enterJelly"
    elseif KingdomPage.isKingdomHome() then
        Logger.info(TAG .. " [detect] 当前在王国首页")
        return "navigate"
    end
    Logger.warn(TAG .. " [detect] 页面识别失败")
    return false, "解除洋菜冻[detect] 页面识别失败"
end

local function navigate(sm)
    Logger.info(TAG .. " [navigate] 王国首页 → 矿山首页")
    if Route.kingdomHomeToMineHome() then
        return "enterJelly"
    end
    Logger.warn(TAG .. " [navigate] 导航到矿山首页失败")
    return false, "解除洋菜冻[navigate] 导航失败"
end

local function enterJelly(sm)
    Logger.info(TAG .. " [enterJelly] 矿山首页 → 解除洋菜冻页面")
    JellyPage.tapEnterBtn()
    if JellyPage.waitJellyPage(30000, 500) then
        return "processPage"
    end
    Logger.warn(TAG .. " [enterJelly] 等待解除洋菜冻页面超时")
    return StateMachine.RETRY
end

local function processPage(sm)
    Logger.info(TAG .. " [processPage] 处理解除洋菜冻页面")

    -- 1. 可全部领取则先领取并结算
    if JellyPage.canClaimAll() then
        Logger.info(TAG .. " [processPage] 检测到可全部领取")
        JellyPage.tapClaimAll()
        Guard.sleep(1000)
        local settled = Color.tapUntilMatch(jellyFeatures.settleBtn, jellyFeatures.feature, {
            timeoutMs = 30000,
            intervalMs = 500,
            tapDelayMs = 800,
            sleepMs = 800,
        })
        if not settled then
            Logger.warn(TAG .. " [processPage] 点击 settleBtn 后页面未恢复")
            return StateMachine.RETRY
        end
    end

    -- 2. OCR 查找「配置」按钮
    local configPoint = JellyPage.findConfigBtn()
    if configPoint then
        Logger.info(TAG .. " [processPage] 找到配置按钮，进入配置界面")
        JellyPage.tapConfigBtn(configPoint)
        if not JellyPage.waitConfigPage(2000, 300) then
            Logger.info(TAG .. " [processPage] 点击配置后未进入配置洋菜冻页面，无可选择洋菜冻，结束任务")
            sm.ctx.jellyRemainSec = nil
            return "returnHome"
        end
        return "configJelly"
    end

    -- 3. 无配置按钮：识别剩余时间
    Logger.info(TAG .. " [processPage] 未找到配置按钮，准备识别剩余时间")
    local remainSec = JellyPage.readRemainTime()
    sm.ctx.jellyRemainSec = remainSec
    return "returnHome"
end

local function configJelly(sm)
    Logger.info(TAG .. " [configJelly] 处理配置洋菜冻界面")

    if JellyPage.canChoose() then
        Logger.info(TAG .. " [configJelly] 可选择，点击选择按钮")
        JellyPage.tapChoose()
        Guard.sleep(1000)
        if JellyPage.waitJellyPage(30000, 500) then
            return "processPage"
        end
        Logger.warn(TAG .. " [configJelly] 选择后等待解除洋菜冻页面超时")
        return StateMachine.RETRY
    end

    -- 不可选择：返回解除洋菜冻页面，再走返回链结束
    Logger.info(TAG .. " [configJelly] 不可选择，返回解除洋菜冻页面")
    sm.ctx.jellyRemainSec = nil
    JellyPage.tapConfigBack()
    if not JellyPage.waitJellyPage(30000, 500) then
        Logger.warn(TAG .. " [configJelly] 返回后等待解除洋菜冻页面超时")
        return StateMachine.RETRY
    end
    return "returnHome"
end

local function returnHome(sm)
    Logger.info(TAG .. " [returnHome] 返回王国首页")

    -- 统一记录冷却，避免任务立即被再次调度
    local remainSec = sm.ctx and sm.ctx.jellyRemainSec
    if remainSec and remainSec > 0 then
        JellySession.enterWait(remainSec)
    else
        JellySession.enterWait()
    end

    -- 解除洋菜冻页 → 矿山首页
    if JellyPage.isJellyPage() then
        JellyPage.tapBack()
        if not MineHomePage.wait(30000) then
            Logger.warn(TAG .. " [returnHome] 返回矿山首页超时")
            return StateMachine.RETRY
        end
    end

    -- 矿山首页 → 王国首页
    if MineHomePage.isCurrent() then
        MineHomePage.tapBack()
        if not KingdomPage.wait(30000) then
            Logger.warn(TAG .. " [returnHome] 返回王国首页超时")
            return StateMachine.RETRY
        end
    end

    if KingdomPage.isKingdomHome() then
        Logger.info(TAG .. " [returnHome] 已回到王国首页")
        return StateMachine.DONE
    end

    Logger.warn(TAG .. " [returnHome] 未知页面，无法返回")
    return StateMachine.RETRY
end

local handlers = {
    detect = detect,
    navigate = navigate,
    enterJelly = enterJelly,
    processPage = processPage,
    configJelly = configJelly,
    returnHome = returnHome,
}

-- ==================== 入口 ====================

function JellyTask.run()
    local cfg = UserConfig.get("mine")
    if cfg.jellyEnabled ~= true then
        Logger.info(TAG .. " 任务未启用，跳过")
        return false
    end

    Logger.info(TAG .. " 任务启动 | jellyEnabled=" .. tostring(cfg.jellyEnabled)
        .. " jellyIntervalSec=" .. tostring(cfg.jellyIntervalSec))

    local ctx = {}
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
        label = "解除洋菜冻",
    })

    if ok then
        Logger.info(TAG .. " 任务完成")
    else
        Logger.warn(TAG .. " 任务结束：" .. tostring(err))
    end
    return ok
end

return JellyTask
