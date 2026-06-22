--[[
模块: 玩法特征库模板
路径: game.常规_玩法名.玩法名_特征库
功能: 集中管理比色、找色、OCR 区域定义
依赖: 无
说明: 特征库只返回表，不写业务逻辑
--]]

local FeatureLib = {}

local common = {
    backBtn = { 1546, 39, 1559, 53 },
}

-- TODO: 替换为实际特征
local xxxHome = {
    feature = { "x|y|color,...", 0.9 },
    enterBtn = { x1, y1, x2, y2 },
    backBtn = common.backBtn,
}

local xxxPage = {
    page = {
        feature = { "x|y|color,...", 0.9 },
    },
    backBtn = { x1, y1, x2, y2 },
    completedTask = {
        -- findMultiColor 参数
        feature = { x1, y1, x2, y2, "firstColor", "offsetColors", dir, sim },
    },
    confirmBtn = { x1, y1, x2, y2 },
    someOcrRect = { x1, y1, x2, y2 },
}

function FeatureLib.xxxHome()
    return xxxHome
end

function FeatureLib.xxxPage()
    return xxxPage
end

return FeatureLib
