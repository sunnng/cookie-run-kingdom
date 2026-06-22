--[[
模块: 脆饼词条参考表
路径: game.功能_洗脆饼.词条库
功能: 游戏内可出现的副词条名称及典型数值区间
--]]

local M = {}

M.entries = {
	{ name = "攻击力", minValue = 3, maxValue = 7.5 },
	{ name = "防御力", minValue = 5, maxValue = 7.5 },
	{ name = "生命值", minValue = 3, maxValue = 15 },
	{ name = "攻击速度", minValue = 3, maxValue = 10 },
	{ name = "会心", minValue = 3, maxValue = 7 },
	{ name = "冷却时间", minValue = 2, maxValue = 6 },
	{ name = "伤害减免", minValue = 5, maxValue = 10 },
	{ name = "会心伤害减免", minValue = 4, maxValue = 10 },
	{ name = "增益效果增强", minValue = 2, maxValue = 5 },
	{ name = "减益效果减免", minValue = 2, maxValue = 5 },
	{ name = "无视伤害减免", minValue = 5, maxValue = 15 },
	{ name = "电属性伤害提升", minValue = 8, maxValue = 15 },
	{ name = "火属性伤害提升", minValue = 8, maxValue = 15 },
	{ name = "暗属性伤害提升", minValue = 8, maxValue = 15 },
	{ name = "毒属性伤害提升", minValue = 8, maxValue = 15 },
}

--- @return string[]
function M.names()
	local list = {}
	for _, entry in ipairs(M.entries) do
		list[#list + 1] = entry.name
	end
	return list
end

--- @param name string
--- @return table|nil
function M.find(name)
	for _, entry in ipairs(M.entries) do
		if entry.name == name then
			return entry
		end
	end
	return nil
end

--- @param name string|nil
--- @return number|nil minValue
--- @return number|nil maxValue
function M.valueBounds(name)
	local entry = M.find(name)
	if not entry then
		return nil , nil
	end
	return entry.minValue , entry.maxValue
end

--- @param name string|nil
--- @param count number|nil
--- @return number|nil minSum
--- @return number|nil maxSum
function M.sumBounds(name , count)
	local minValue , maxValue = M.valueBounds(name)
	if not minValue or not count or count < 1 then
		return nil , nil
	end
	count = math.min(4 , math.floor(count))
	return minValue * count , maxValue * count
end

--- @param name string|nil
--- @return string
function M.rangeHint(name)
	if type(name) ~= "string" or name == "" then
		return ""
	end
	local entry = M.find(name)
	if not entry then
		return ""
	end
	return string.format("范围 %g%%~%g%%", entry.minValue, entry.maxValue)
end

return M
