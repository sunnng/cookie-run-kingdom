local Color = require("lib.color")
local Touch = require("lib.touch")

local KingdomFeatureLib = require("game.通用_王国.特征库")

local KingdomPage = {}

local kingdomHomeFeatures = KingdomFeatureLib.home()
local kingdomEventFeatures = KingdomFeatureLib.event()
local kingdomAdventureFeatures = KingdomFeatureLib.adventure()

function KingdomPage.isKingdomHome()
	return Color.match(kingdomHomeFeatures.feature)
end

function KingdomPage.tapEventBtn()
	Touch.tapArea(kingdomHomeFeatures.eventBtn , 1200)
end

function KingdomPage.tapMineBtn()
	Touch.tapArea(kingdomEventFeatures.mineBtn , 1200)
end

function KingdomPage.tapAdventureBtn()
	Touch.tapArea(kingdomHomeFeatures.adventureBtn , 1200)
end

function KingdomPage.isAdventurePage()
	return Color.match(kingdomAdventureFeatures.feature)
end

--- @param timeoutMs number|nil
--- @return boolean
function KingdomPage.waitAdventure(timeoutMs)
	return Color.waitMatch(kingdomAdventureFeatures.feature , timeoutMs or 30000 , 500 , 800)
end

--- 等待进入王国首页
--- @param timeoutMs number|nil 默认 90000
--- @return boolean
function KingdomPage.wait(timeoutMs)
	return Color.waitMatch(kingdomHomeFeatures.feature , timeoutMs or 90000 , 500 , 1000)
end

--- 王国首页特征常量（供外部 Color.waitMatch 等使用）
KingdomPage.HOME_FEATURE = kingdomHomeFeatures.feature

return KingdomPage
