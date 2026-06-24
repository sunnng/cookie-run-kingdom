local Color = require("lib.color")
local Touch = require("lib.touch")

local MineFeatureLib = require("game.常规_未知的地底矿山.矿山_特征库")

local MineHomePage = {}

local mineHomeFeatures = MineFeatureLib.mineHome()

function MineHomePage.isCurrent()
	return Color.match(mineHomeFeatures.feature)
end

function MineHomePage.hasMiningCompletedTask()
	return Color.match(mineHomeFeatures.hasMiningCompletedTaskFeature)
end

function MineHomePage.wait()
	return Color.waitMatch(mineHomeFeatures.feature , 60000 , 500 , 1000)
end

function MineHomePage.waitGone()
	return Color.waitGone(mineHomeFeatures.feature , 30000 , 500)
end

function MineHomePage.tapVenture()
	Touch.tapArea(mineHomeFeatures.ventureBtn , 1000)
end

function MineHomePage.tapMining()
	Touch.tapArea(mineHomeFeatures.miningBtn , 1000)
end

function MineHomePage.tapBattleBtn()
	Touch.tapArea(mineHomeFeatures.battleBtn , 1000)
end

function MineHomePage.tapBack()
	Touch.tapArea(mineHomeFeatures.backBtn , 1000)
end

return MineHomePage
