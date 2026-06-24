--[[
模块: 梦幻繁星岛页面
路径: game.常规_梦幻繁星岛.繁星岛_页面
功能: 页面识别与交互 API
依赖: lib.color, lib.touch, lib.logger
--]]

local Color = require("lib.color")
local Touch = require("lib.touch")
local Logger = require("lib.logger")

local Features = require("game.常规_梦幻繁星岛.繁星岛_坐标库")

local Page = {}
local TAG = "[梦幻繁星岛.页面]"

local home = Features.home
local manual = Features.航海手册
local vanilla = Features.纯香草小岛
local task = Features.任务

local function hasFeature(feature)
	return type(feature) == "table" and feature[1] ~= nil
end

-- ========== 首页 ==========

function Page.isHomePage()
	return hasFeature(home.feature) and Color.match(home.feature)
end

function Page.waitHomePage(timeoutMs , intervalMs)
	if not hasFeature(home.feature) then
		Logger.warn(TAG .. " home.feature 未配置")
		return false
	end
	return Color.waitMatch(home.feature , timeoutMs or 30000 , intervalMs or 500)
end

function Page.tapSailingManual(delayMs)
	if not home.航海手册_按钮 then
		Logger.warn(TAG .. " 航海手册_按钮 未配置")
		return false
	end
	Touch.tapArea(home.航海手册_按钮 , delayMs or 1000)
	return true
end

function Page.tapTaskBtn(delayMs)
	if not home.taskBtn then
		Logger.warn(TAG .. " taskBtn 未配置")
		return false
	end
	Touch.tapArea(home.taskBtn , delayMs or 1000)
	return true
end

function Page.tapBackToKingdom(delayMs)
	if not home.backBtn then
		Logger.warn(TAG .. " home.backBtn 未配置")
		return false
	end
	Touch.tapArea(home.backBtn , delayMs or 1200)
	return true
end

-- ========== 航海手册页 ==========

function Page.isManualPage()
	return hasFeature(manual.feature) and Color.match(manual.feature)
end

function Page.waitManualPage(timeoutMs , intervalMs)
	if not hasFeature(manual.feature) then
		Logger.warn(TAG .. " 航海手册.feature 未配置")
		return false
	end
	return Color.waitMatch(manual.feature , timeoutMs or 10000 , intervalMs or 500)
end

function Page.tapLoginIsland(delayMs)
	if not manual.登陆回忆小岛_按钮 then
		Logger.warn(TAG .. " 登陆回忆小岛_按钮 未配置")
		return false
	end
	Touch.tapArea(manual.登陆回忆小岛_按钮 , delayMs or 1000)
	return true
end

-- ========== 纯香草小岛页 ==========

function Page.isVanillaIslandPage()
	return hasFeature(vanilla.feature) and Color.match(vanilla.feature)
end

function Page.waitVanillaIslandPage(timeoutMs , intervalMs)
	if not hasFeature(vanilla.feature) then
		Logger.warn(TAG .. " 纯香草小岛.feature 未配置")
		return false
	end
	return Color.waitMatch(vanilla.feature , timeoutMs or 10000 , intervalMs or 500)
end

function Page.tapBackFromVanilla(delayMs)
	if not vanilla.backBtn then
		Logger.warn(TAG .. " 纯香草小岛.backBtn 未配置")
		return false
	end
	Touch.tapArea(vanilla.backBtn , delayMs or 1200)
	return true
end

-- ========== 任务页 ==========

function Page.isTaskPage()
	return hasFeature(task.feature) and Color.match(task.feature)
end

function Page.waitTaskPage(timeoutMs , intervalMs)
	if not hasFeature(task.feature) then
		Logger.warn(TAG .. " 任务.feature 未配置")
		return false
	end
	return Color.waitMatch(task.feature , timeoutMs or 10000 , intervalMs or 500)
end

function Page.tapBackFromTask(delayMs)
	if not task.backBtn then
		Logger.warn(TAG .. " 任务.backBtn 未配置")
		return false
	end
	Touch.tapArea(task.backBtn , delayMs or 1200)
	return true
end

--- 查找可领奖按钮
--- @return number|nil x
--- @return number|nil y
function Page.findClaimableBtn()
	local def = task.可领奖_按钮
	if not def then
		Logger.warn(TAG .. " 可领奖_按钮 未配置")
		return nil , nil
	end
	return Color.find(def)
end

function Page.tapClaimableBtn(x , y , delayMs)
	Touch.tapR(x , y , delayMs or 800)
end

--- 领奖后可能出现奖励弹窗，点击屏幕中央空白处尝试关闭
function Page.dismissRewardPopupIfNeeded()
	-- 先等待任务页特征恢复，说明弹窗已关闭
	if Page.isTaskPage() then
		return
	end
	-- 尝试点击屏幕中央空白区域关闭弹窗
	Touch.tapR(800 , 450 , 500)
	Color.waitMatch(task.feature , 5000 , 300)
end

return Page
