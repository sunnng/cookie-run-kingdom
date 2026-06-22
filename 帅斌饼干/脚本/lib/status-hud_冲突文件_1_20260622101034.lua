--[[
模块: 顶部状态 HUD
路径: lib.status-hud
功能: 屏幕顶部单行状态栏（createHUD / showHUD）
依赖: config
设备: 1600×900，布局见 config STATIC.HUD
--]]

local AppConfig = require("config")

local StatusHud = {}

local hudId = nil
local lastRendered = nil

local PREFIX = "帅斌饼干"

--- @return table|nil
local function cfg()
    return AppConfig.hudStatic()
end

--- @return string
local function line(...)
    local parts = { ... }
    local out = {}
    for i = 1, #parts do
        if parts[i] and parts[i] ~= "" then
            out[#out + 1] = parts[i]
        end
    end
    return table.concat(out, " · ")
end

--- @param text string
local function render(text)
    local c = cfg()
    if not c or c.enabled == false then
        return
    end
    if not hudId then
        return
    end
    if text == lastRendered then
        return
    end
    lastRendered = text

    showHUD(
        hudId,
        text,
        c.size or 10,
        c.color or "0xffff9100",
        c.bg or "0xff001428",
        c.pos or 0,
        c.x or 0,
        c.y or 0,
        c.width or 1600,
        c.height or 32,
        c.pl or 20,
        c.pt or 3,
        c.pr or 20,
        c.pb or 3,
        c.align_text or 1
    )
end

--- 初始化 HUD（运行时启动时调用一次）
function StatusHud.init()
    local c = cfg()
    if not c or c.enabled == false then
        return
    end
    if hudId then
        return
    end
    hudId = createHUD()
    render(line(PREFIX, "就绪"))
end

--- 销毁 HUD
function StatusHud.destroy()
    if hudId then
        hideHUD(hudId)
        hudId = nil
        lastRendered = nil
    end
end

--- 直接显示一行文案
--- @param text string
function StatusHud.show(_tone, text)
    render(text)
end

--- @param _tone string|nil 保留兼容，不改变配色
--- @param text string
function StatusHud.set(_tone, text)
    render(line(PREFIX, text))
end

--- 空闲 / 等待任务
--- @param reason string|nil
function StatusHud.setIdle(reason)
    if reason then
        render(line(PREFIX, reason))
    else
        render(line(PREFIX, "空闲", "等待任务"))
    end
end

--- 执行任务
--- @param taskName string
--- @param detail string|nil
function StatusHud.setTask(taskName, detail)
    render(line(PREFIX, taskName, detail))
end

local MINE_STATE_LABEL = {
    detect = "识别页面" ,
    navigate = "导航" ,
    prepare = "准备启动" ,
    running = "读层判断" ,
    polling = "近距守候" ,
    settle = "结算" ,
    farWait = "远距回城" ,
    idle = "远距挂机" ,
}

--- 矿山勘查专用（调试向，尽量在一行内展示状态机关键量）
--- @param opts table
---   state string|nil   detect/navigate/prepare/running/polling/settle/farWait/idle
---   floor number|nil   当前层（OCR）
---   target number|nil  目标层
---   gap number|nil     |目标-当前| 层差
---   farGap number|nil  近距阈值
---   ocrInSec number|nil  下次 OCR 剩余秒（polling）
---   farWaitSec number|nil 远距等待剩余秒
---   retry number|nil   当前状态主动重试次数
---   cfgHint string|nil 配置摘要（启动时）
---   extra string|nil   附加说明
function StatusHud.setMineSurvey(opts)
    opts = opts or {}
    local parts = { PREFIX , "矿山勘查" }

    if opts.state then
        parts[#parts + 1] = MINE_STATE_LABEL[opts.state] or opts.state
    end

    local target = opts.target
    if target then
        if opts.floor then
            if opts.gap then
                parts[#parts + 1] = string.format("层%d→%d 差%d" , opts.floor , target , opts.gap)
            else
                parts[#parts + 1] = string.format("层%d→%d" , opts.floor , target)
            end
        else
            parts[#parts + 1] = string.format("目标%d层" , target)
        end
    end

    if opts.farGap then
        parts[#parts + 1] = string.format("近距≤%d" , opts.farGap)
    end

    if opts.ocrInSec ~= nil then
        parts[#parts + 1] = string.format("OCR %ds" , math.max(0 , math.floor(opts.ocrInSec)))
    end

    if opts.farWaitSec and opts.farWaitSec > 0 then
        parts[#parts + 1] = string.format("远距 %ds" , math.floor(opts.farWaitSec))
    end

    if opts.retry and opts.retry > 0 then
        parts[#parts + 1] = string.format("重试%d" , opts.retry)
    end

    if opts.cfgHint and opts.cfgHint ~= "" then
        parts[#parts + 1] = opts.cfgHint
    end

    if opts.extra and opts.extra ~= "" then
        parts[#parts + 1] = opts.extra
    end

    render(line(table.unpack(parts)))
end

local MINING_STATE_LABEL = {
    detect = "识别页面" ,
    navigate = "导航" ,
    precheck = "首页预检" ,
    miningPage = "开采页" ,
    claimTap = "点击完成" ,
    claimConfirm = "确认奖励" ,
    checkSlot = "检查栏位" ,
    selectFlow = "选矿选卡" ,
    startFlow = "启动矿卡" ,
    recordDone = "记录完成" ,
    idle = "busy 挂机" ,
}

--- 矿山开采专用
--- @param opts table state?, selected?, quota?, busySec?, retry?, extra?
function StatusHud.setMineMining(opts)
    opts = opts or {}
    local parts = { PREFIX , "矿山开采" }

    if opts.state then
        parts[#parts + 1] = MINING_STATE_LABEL[opts.state] or opts.state
    end

    if opts.selected and opts.quota then
        parts[#parts + 1] = string.format("选卡 %d/%d" , opts.selected , opts.quota)
    elseif opts.quota then
        parts[#parts + 1] = string.format("上限 %d" , opts.quota)
    end

    if opts.busySec and opts.busySec > 0 then
        parts[#parts + 1] = string.format("busy %ds" , math.floor(opts.busySec))
    end

    if opts.retry and opts.retry > 0 then
        parts[#parts + 1] = string.format("重试%d" , opts.retry)
    end

    if opts.extra and opts.extra ~= "" then
        parts[#parts + 1] = opts.extra
    end

    render(line(table.unpack(parts)))
end

--- 矿山勘查 + 开采同时等待（调度跳过 / 空闲挂机）
--- @param opts table surveySec?, miningSec?, target?, extra?
function StatusHud.setMineWait(opts)
    opts = opts or {}
    local parts = { PREFIX , "矿山" }

    local surveySec = opts.surveySec
    local miningSec = opts.miningSec
    local hasSurvey = type(surveySec) == "number" and surveySec > 0
    local hasMining = type(miningSec) == "number" and miningSec > 0

    if hasSurvey then
        if opts.target then
            parts[#parts + 1] = string.format("勘查远距 %ds(目标%d层)" , math.floor(surveySec) , opts.target)
        else
            parts[#parts + 1] = string.format("勘查远距 %ds" , math.floor(surveySec))
        end
    end

    if hasMining then
        parts[#parts + 1] = string.format("开采 %ds" , math.floor(miningSec))
    end

    if opts.extra and opts.extra ~= "" then
        parts[#parts + 1] = opts.extra
    end

    if not hasSurvey and not hasMining then
        render(line(PREFIX , "矿山" , opts.extra or "等待"))
        return
    end

    render(line(table.unpack(parts)))
end

--- 洗脆饼专用
--- @param opts table current?, max?, extra?
function StatusHud.setBiscuitReroll(opts)
    opts = opts or {}
    local max = opts.max or 500
    local parts = { PREFIX, "洗脆饼" }
    if opts.current then
        parts[#parts + 1] = string.format("%d/%d", opts.current, max)
    else
        parts[#parts + 1] = string.format("目标 %d 次", max)
    end
    if opts.extra then
        parts[#parts + 1] = opts.extra
    end
    render(line(table.unpack(parts)))
end

--- 带 HUD 刷新的休眠（轮询等待时用，分片 sleep 并清弹窗）
--- @param totalSec number
--- @param _tone string|nil
--- @param tag string
--- @param makeDetail fun(remainingSec:number):string|nil
--- @param stepSec number|nil
function StatusHud.countdownSleep(totalSec, _tone, tag, makeDetail, stepSec)
    local Guard = require("core.guard")
    local step = stepSec or 5
    local left = math.max(0, math.floor(totalSec))
    while left > 0 do
        local chunk = math.min(left, step)
        if makeDetail then
            render(line(PREFIX, tag, makeDetail(left)))
        end
        Guard.sleep(chunk * 1000, 500)
        left = left - chunk
    end
end

return StatusHud
