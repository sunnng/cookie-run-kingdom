--[[
模块: 通用工具
路径: lib.utils
--]]

local U = {}

function U.parseNumber(text)
	if type(text) == "number" then
		return text
	end
	if type(text) ~= "string" then
		return nil
	end
	local clean = text:gsub("[^0-9]" , "")
	if clean == "" then
		return nil
	end
	return tonumber(clean)
end

function U.parseStamina(text)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	text = text:gsub("%s" , "")
	local currentStr , maxStr = text:match("([%d%,%.]+)/([%d%,%.]+)")
	if not currentStr or not maxStr then
		return nil
	end
	local function cleanNum(s)
		return tonumber((s:gsub("," , ""):gsub("%." , "")))
	end
	local current = cleanNum(currentStr)
	local maxNum = cleanNum(maxStr)
	if not current or not maxNum then
		return nil
	end
	return { current = current , max = maxNum , raw = text }
end

function U.generateNewPos(newBaseX , newBaseY , baseX , baseY , x1 , y1 , x2 , y2)
	local dx = newBaseX - baseX
	local dy = newBaseY - baseY
	return { x1 + dx , y1 + dy , x2 + dx , y2 + dy }
end

function U.keepHanAlphaNum(str)
	if not str then
		return ""
	end
	return tostring(str):gsub("[^%w%u%l一-龥]" , "")
end

return U
