--[[
模块: 比色 / 找色 / 等待页面
路径: lib.color
功能: cmpColorExT 多点比色、findMultiColor 封装、wait/tapUntilMatch
依赖: lib.touch
设备: 固定 1600×900 @ 320dpi，坐标原样使用
--]]

local Touch = require("lib.touch")

local Color = {}

local NOT_FOUND = -1
local guardHook = nil

--- 注册主线程守卫回调（由 Runtime 注入 Guard.check）
--- @param fn function|nil
function Color.setGuardHook(fn)
	guardHook = fn
end

--- 执行一次守卫扫描（wait 轮询内调用）
function Color.tickGuard()
	if guardHook then
		guardHook()
	end
end

local function waitInterval(intervalMs)
	Color.tickGuard()
	sleep(intervalMs)
end

local function sleepFragment(ms, stepMs)
	stepMs = stepMs or 500
	local left = math.max(0, math.floor(ms))
	while left > 0 do
		Color.tickGuard()
		local chunk = math.min(left, stepMs)
		sleep(chunk)
		left = left - chunk
	end
end

--- 当前挂钟毫秒（tickCount；sleep 期间也会推进，优于 os.clock CPU 时间）
--- @return number
local function nowMs()
	return tickCount()
end

--- @param target table|function 单特征、多特征表，或自定义判定函数
--- @return boolean
--- @return number|string|nil
local function isFeatureMatched(target)
	if type(target) == "function" then
		return target() == true
	end
	if type(target) ~= "table" then
		return false
	end
	if type(target[1]) == "string" then
		return Color.match(target)
	end
	return Color.matchAny(target)
end

--- 单特征比色是否匹配
--- @param feature table { "x|y|color,...", sim }
--- @return boolean
function Color.match(feature)
	return cmpColorExT(feature) == 1
end

--- 多个特征任一匹配
--- @param features table 数组或键值表
--- @return boolean matched
--- @return number|string|nil which
function Color.matchAny(features)
	if #features > 0 then
		for i, f in ipairs(features) do
			if Color.match(f) then
				return true, i
			end
		end
	else
		for k, f in pairs(features) do
			if Color.match(f) then
				return true, k
			end
		end
	end
	return false, nil
end

--- 通用匹配（Guard 等用）
--- @param target table|function
--- @return boolean
--- @return number|string|nil
function Color.any(target)
	return isFeatureMatched(target)
end

--- 轮询直到 features 中任一匹配
--- @param features table|function
--- @param timeoutMs number|nil 默认 10000
--- @param intervalMs number|nil 默认 500
--- @return boolean
--- @return number|string|nil
function Color.wait(features, timeoutMs, intervalMs)
	timeoutMs = timeoutMs or 10000
	intervalMs = intervalMs or 500

	local ok, which = isFeatureMatched(features)
	if ok then
		return true, which
	end

	local deadline = nowMs() + timeoutMs
	while nowMs() < deadline do
		ok, which = isFeatureMatched(features)
		if ok then
			return true, which
		end
		waitInterval(intervalMs)
	end
	return false, nil
end

--- 轮询直到单特征匹配
--- @param feature table
--- @param timeoutMs number|nil
--- @param intervalMs number|nil
--- @param sleepMs number|nil 匹配成功后额外等待
--- @return boolean
function Color.waitMatch(feature, timeoutMs, intervalMs, sleepMs)
	timeoutMs = timeoutMs or 10000
	intervalMs = intervalMs or 500

	if Color.match(feature) then
		if sleepMs then
			sleepFragment(sleepMs, intervalMs)
		end
		return true
	end

	local deadline = nowMs() + timeoutMs
	while nowMs() < deadline do
		if Color.match(feature) then
			if sleepMs then
				sleepFragment(sleepMs, intervalMs)
			end
			return true
		end
		waitInterval(intervalMs)
	end
	return false
end

--- 轮询直到特征不再匹配
--- @param feature table|function
--- @param timeoutMs number|nil
--- @param intervalMs number|nil
--- @return boolean
function Color.waitGone(feature, timeoutMs, intervalMs)
	timeoutMs = timeoutMs or 10000
	intervalMs = intervalMs or 500

	if not isFeatureMatched(feature) then
		return true
	end

	local deadline = nowMs() + timeoutMs
	while nowMs() < deadline do
		if not isFeatureMatched(feature) then
			return true
		end
		waitInterval(intervalMs)
	end
	return false
end

--- 执行一次点击：区域、坐标或自定义函数
--- @param target table|function
--- @param tapDelayMs number|nil
--- @return boolean
local function performTap(target, tapDelayMs)
	if type(target) == "function" then
		target()
		return true
	end
	if type(target) ~= "table" then
		return false
	end
	if type(target.x) == "number" and type(target.y) == "number" then
		Touch.tapR(target.x, target.y, tapDelayMs)
		return true
	end
	if type(target[1]) == "number" and type(target[2]) == "number"
			and type(target[3]) == "number" and type(target[4]) == "number"
			and target[3] > target[1] and target[4] > target[2] then
		Touch.tapArea(target, tapDelayMs)
		return true
	end
	if type(target[1]) == "number" and type(target[2]) == "number" then
		Touch.tapR(target[1], target[2], tapDelayMs)
		return true
	end
	return false
end

--- 持续点击直到目标特征出现
--- @param tapTarget table|function
--- @param feature table|function
--- @param opts table|nil { timeoutMs, intervalMs, tapDelayMs, sleepMs, maxTaps }
--- @return boolean ok
--- @return number|string|nil which
function Color.tapUntilMatch(tapTarget, feature, opts)
	if not tapTarget then
		return false
	end

	opts = opts or {}
	local timeoutMs = opts.timeoutMs or 15000
	local intervalMs = opts.intervalMs or 500
	local tapDelayMs = opts.tapDelayMs or 800
	local maxTaps = opts.maxTaps
	local sleepMs = opts.sleepMs

	local tapCount = 0
	local deadline = nowMs() + timeoutMs
	while nowMs() < deadline do
		local ok, which = isFeatureMatched(feature)
		if ok then
			if sleepMs then
				sleepFragment(sleepMs, intervalMs)
			end
			return true, which
		end
		if maxTaps and tapCount >= maxTaps then
			break
		end
		Color.tickGuard()
		if not performTap(tapTarget, tapDelayMs) then
			return false
		end
		tapCount = tapCount + 1
		waitInterval(intervalMs)
	end
	return false, nil
end

--- 在区域内找色
--- @param def table {x1,y1,x2,y2, firstColor, offsetColors, dir, sim}
--- @return number|nil x
--- @return number|nil y
function Color.find(def)
	if type(def) ~= "table" or type(def[5]) ~= "string" then
		return nil, nil
	end

	local x, y = findMultiColor(
		def[1], def[2], def[3], def[4],
		def[5], def[6],
		def[7] or 0, def[8] or 0.9
	)
	if x ~= NOT_FOUND and y ~= NOT_FOUND then
		return x, y
	end
	return nil, nil
end

--- 找色并点击
--- @param def table
--- @param delayMs number|nil
--- @return boolean
function Color.tapFind(def, delayMs)
	local x, y = Color.find(def)
	if not x then
		return false
	end
	Touch.tapR(x, y, delayMs)
	return true
end

--- 找色返回首个坐标点
--- @param def table
--- @return table|nil point {x, y}
function Color.findPoint(def)
	local x, y = Color.find(def)
	if x then
		return { x = x, y = y }
	end
	return nil
end

--- 区域内找色返回全部坐标
--- @param def table {x1,y1,x2,y2, firstColor, offsetColors, dir, sim}
--- @return table[] points
function Color.findAll(def)
	if type(def) ~= "table" or type(def[5]) ~= "string" then
		return {}
	end

	local ret = findMultiColorAll(
		def[1], def[2], def[3], def[4],
		def[5], def[6],
		def[7] or 0, def[8] or 0.9
	)
	if ret == nil then
		return {}
	end

	local points = {}

	local function add(x, y)
		if x and y and x ~= NOT_FOUND and y ~= NOT_FOUND then
			points[#points + 1] = { x = math.floor(x), y = math.floor(y) }
		end
	end

	if type(ret) == "table" and ret.x and ret.y then
		add(ret.x, ret.y)
		return points
	end

	for _, item in ipairs(ret) do
		if type(item) == "table" then
			if item.x and item.y then
				add(item.x, item.y)
			elseif item[1] and item[2] then
				add(item[1], item[2])
			end
		end
	end

	if #points == 0 then
		for i = 1, #ret - 1, 2 do
			if type(ret[i]) == "number" and type(ret[i + 1]) == "number" then
				add(ret[i], ret[i + 1])
			end
		end
	end

	return points
end

return Color
