local Color = require("lib.color")
local Touch = require("lib.touch")
local Ocr = require("lib.ocr")

local FeatureLib = require("game.常规_未知的地底矿山.矿山_特征库")

local mineVenturePage = {}

local mineVentureFeatures = FeatureLib.mineVenture()

-- 判断是否在矿山域
function mineVenturePage.isMineVentureDomain()
	return Color.matchAny({
		mineVentureFeatures.setup.feature ,
		mineVentureFeatures.ready.feature ,
		mineVentureFeatures.running.feature ,
		mineVentureFeatures.settle.feature
	})
end

-- 等待进入矿山域
function mineVenturePage.waitMineVentureDomain()
	return Color.wait({
		mineVentureFeatures.setup.feature ,
		mineVentureFeatures.ready.feature ,
		mineVentureFeatures.running.feature ,
		mineVentureFeatures.settle.feature
	} , 60000 , 500)
end

-- 判断是否勘查中
function mineVenturePage.isSetup()
	return Color.match(mineVentureFeatures.setup.feature)
end

-- 点击停止勘查按钮
function mineVenturePage.tapStopBtn()
	return Touch.tapArea(mineVentureFeatures.running.stopBtn , 500)
end

-- 判断是否勘查中
function mineVenturePage.isReady()
	return Color.match(mineVentureFeatures.ready.feature)
end

-- 判断是否勘查中
function mineVenturePage.isRunning()
	return Color.match(mineVentureFeatures.running.feature)
end

-- 准备
function mineVenturePage.setup()
	Touch.tapArea(mineVentureFeatures.setup.autoSelectBtn , 500)
	if not Color.waitMatch(mineVentureFeatures.ready.feature , 30000 , 500 , 1000) then
		return false
	end
	
	Touch.tapArea(mineVentureFeatures.ready.startBtn , 500)
	if not Color.waitMatch(mineVentureFeatures.dialogInfo.feature , 10000 , 500 , 1000) then
		return false
	end
	
	Touch.tapArea(mineVentureFeatures.dialogInfo.confirmBtn , 500)
	if not Color.waitMatch(mineVentureFeatures.dialogConfirmCookie.feature , 10000 , 500 , 1000) then
		return false
	end
	
	Touch.tapArea(mineVentureFeatures.dialogConfirmCookie.confirmBtn , 500)
	if not Color.waitMatch(mineVentureFeatures.running.feature , 15000 , 500 , 1000) then
		return false
	end
	
	return true
end

-- 停止勘查
function mineVenturePage.stopVenture()
	mineVenturePage.tapStopBtn()
	if not Color.waitMatch(mineVentureFeatures.dialogStop.feature , 10000 , 500 , 1000) then
		return false
	end
	
	Touch.tapArea(mineVentureFeatures.dialogStop.confirmStopBtn , 500)
	Color.tapUntilMatch(
	mineVentureFeatures.settle.finishBtn ,
	mineVentureFeatures.setup.feature ,
	{ timeoutMs = 20000 , tapDelayMs = 800 , intervalMs = 500 , sleepMs = 500 }
	)
	
	return true
end

function mineVenturePage.getCurrentFloor()
	local currentFloor = Ocr.number(mineVentureFeatures.running.floorOcr)
	return currentFloor
end

function mineVenturePage.tapBackBtn()
	Touch.tapArea(mineVentureFeatures.backBtn, 1000)
end

return mineVenturePage
