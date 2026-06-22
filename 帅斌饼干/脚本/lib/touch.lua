--[[
模块: 触控
路径: lib.touch
功能: 点击、按键、增强滑动
依赖: 平台 tap / touchDown / touchMoveEx / touchUp / keyPress
设备: 固定 1600×900 @ 320dpi，坐标原样使用
--]]

local Touch = {}

local DEFAULT_FINGER_ID = 1

local function jitter(v, r)
	r = r or 3
	return v + math.random(-r, r)
end

local function normalizeSwipeOpts(opts)
	if type(opts) == "number" then
		return { moveMs = opts }
	end
	return opts or {}
end

--- 点击坐标（抖动后 tap）
--- @param x number
--- @param y number
--- @param delayMs number|nil
function Touch.tapR(x, y, delayMs)
	tap(jitter(x), jitter(y))
	if delayMs then
		sleep(delayMs)
	else
		sleep(math.random(300, 600))
	end
end

--- 点击坐标（tapR 别名）
--- @param x number
--- @param y number
--- @param delayMs number|nil
function Touch.tapXy(x, y, delayMs)
	Touch.tapR(x, y, delayMs)
end

--- 在矩形区域内随机点击
--- @param rect table {左,上,右,下}
--- @param delayMs number|nil
function Touch.tapArea(rect, delayMs)
	local x = math.random(math.min(rect[1], rect[3]), math.max(rect[1], rect[3]))
	local y = math.random(math.min(rect[2], rect[4]), math.max(rect[2], rect[4]))
	Touch.tapR(x, y, delayMs)
end

--- 区域为空时跳过
--- @param rect table|nil {左,上,右,下}
--- @param delayMs number|nil
--- @return boolean 是否已点击
function Touch.tapAreaSafe(rect, delayMs)
	if not rect then
		return false
	end
	Touch.tapArea(rect, delayMs)
	return true
end

--- 按返回键
--- @param delayMs number|nil
function Touch.pressBack(delayMs)
	keyPress("back")
	if delayMs then
		sleep(delayMs)
	end
end

--- 增强滑动（touchMoveEx）
--- @param opts table { x1, y1, x2, y2, moveMs, holdMs, downMs, steps, pauseMs, upMs, id }
---  x1, y1：起点坐标，手指按下的位置。
--- x2, y2：终点坐标，手指移动到的位置。
--- moveMs：从起点滑到终点的总耗时，默认 600 毫秒。越大越慢。
--- holdMs：滑到终点后，松手前停留多久，默认 200 毫秒。
--- downMs：按下起点后，开始移动前等待多久，默认 50 毫秒。
--- steps：把滑动拆成几段移动，默认 1。比如 steps = 5 会分 5 次移动，更像连续拖动。
--- pauseMs：多段滑动时，每段之间暂停多久，默认 0。只有 steps > 1 时有意义。
--- upMs：松手后再等待多久，默认 0。
--- id：手指 ID，默认 1。一般单指不用传。
--- @return boolean
function Touch.swipeEx(opts)
	opts = normalizeSwipeOpts(opts)
	local id = opts.id or DEFAULT_FINGER_ID
	local x1, y1 = opts.x1, opts.y1
	local x2, y2 = opts.x2, opts.y2
	if not x1 or not y1 or not x2 or not y2 then
		error("Touch.swipeEx 需要 x1,y1,x2,y2")
	end

	local moveMs = math.max(1, math.floor(opts.moveMs or 600))
	local holdMs = math.max(0, math.floor(opts.holdMs or 200))
	local downMs = math.max(0, math.floor(opts.downMs or 50))
	local steps = math.max(1, math.floor(opts.steps or 1))
	local pauseMs = math.max(0, math.floor(opts.pauseMs or 0))
	local upMs = math.max(0, math.floor(opts.upMs or 0))

	touchDown(id, math.floor(x1), math.floor(y1))
	if downMs > 0 then
		sleep(downMs)
	end

	local segMs = math.max(1, math.floor(moveMs / steps))
	for i = 1, steps do
		local t = i / steps
		local xi = x1 + (x2 - x1) * t
		local yi = y1 + (y2 - y1) * t
		touchMoveEx(id, math.floor(xi), math.floor(yi), segMs)
		if pauseMs > 0 and i < steps then
			sleep(pauseMs)
		end
	end

	if holdMs > 0 then
		sleep(holdMs)
	end

	local ok = touchUp(id)
	if upMs > 0 then
		sleep(upMs)
	end
	return ok
end

--- 水平滑动
--- @param x1 number
--- @param x2 number
--- @param y number
--- @param opts table|number|nil
--- @return boolean
function Touch.swipeX(x1, x2, y, opts)
	opts = normalizeSwipeOpts(opts)
	opts.x1 = x1
	opts.y1 = y
	opts.x2 = x2
	opts.y2 = y
	return Touch.swipeEx(opts)
end

--- 垂直滑动
--- @param y1 number
--- @param y2 number
--- @param x number
--- @param opts table|number|nil
--- @return boolean
function Touch.swipeY(y1, y2, x, opts)
	opts = normalizeSwipeOpts(opts)
	opts.x1 = x
	opts.y1 = y1
	opts.x2 = x
	opts.y2 = y2
	return Touch.swipeEx(opts)
end

return Touch
