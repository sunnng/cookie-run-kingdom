--[[
模块: 弹窗处理
路径: lib.dialog
功能: 通用弹窗对象，统一识别、确认/取消/不再显示点击，支持 ifVisible（Guard）与 flow（业务流程）；resolveUntilIdle / resolveAfterPrimary 处理双弹窗
依赖: lib.color, lib.touch, lib.logger, core.guard
--]]

local Color = require("lib.color")
local Touch = require("lib.touch")
local Logger = require("lib.logger")
local Guard = require("core.guard")

local Dialog = {}
Dialog.__index = Dialog

local DEFAULT_TAG = "[Dialog]"

--- @param raw table|nil
--- @return table
local function normalizeDef(raw)
	if type(raw) ~= "table" then
		return {}
	end
	return {
		name = raw.name or raw["名称"],
		feature = raw.feature or raw["特征"],
		confirmBtn = raw.confirmBtn or raw.confirm or raw.buyBtn or raw["按钮_确认"],
		cancelBtn = raw.cancelBtn or raw.cancel or raw.closeBtn,
		neverAgainBtn = raw.neverAgainBtn or raw.todayNotAskAgain,
	}
end

--- @param target table|nil
--- @param tapDelayMs number|nil
--- @return boolean
local function performTap(target, tapDelayMs)
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

--- @param opts table|nil
--- @param defaultMode string|nil
--- @return table
local function mergeHandleOpts(opts, defaultMode)
	opts = opts or {}
	return {
		mode = opts.mode or defaultMode or "flow",
		action = opts.action or "confirm",
		neverAgain = opts.neverAgain == true,
		waitAppearMs = opts.waitAppearMs,
		waitGoneMs = opts.waitGoneMs,
		required = opts.required == true,
		tapDelayMs = opts.tapDelayMs or 800,
		intervalMs = opts.intervalMs or 500,
	}
end

--- @return number
local function nowMs()
	return tickCount()
end

--- @param item table|Dialog
--- @param tag string|nil
--- @return table Dialog
local function ensureDialog(item, tag)
	if getmetatable(item) == Dialog then
		return item
	end
	if type(item) ~= "table" then
		return Dialog.new({}, { tag = tag })
	end
	if item.dialog then
		return item.dialog
	end
	if item.def then
		return Dialog.new(item.def, { tag = item.tag or tag })
	end
	return Dialog.new(item, { tag = item.tag or tag })
end

--- @param candidates table
--- @return table
local function sortByPriority(candidates)
	local list = {}
	for i, c in ipairs(candidates) do
		list[i] = c
	end
	table.sort(list, function(a, b)
		if a.priority == b.priority then
			return (a.name or "") < (b.name or "")
		end
		return (a.priority or 0) > (b.priority or 0)
	end)
	return list
end

--- @param sorted table
--- @return table|nil
local function findFirstVisibleCandidate(sorted)
	for _, c in ipairs(sorted) do
		if (not c.when or c.when()) and c.dialog:isVisible() then
			return c
		end
	end
	return nil
end

--- @param rawDef table
--- @param opts table|nil { tag }
--- @return table
function Dialog.new(rawDef, opts)
	opts = opts or {}
	local self = setmetatable({
		def = normalizeDef(rawDef),
		tag = opts.tag or DEFAULT_TAG,
	}, Dialog)
	return self
end

--- @return boolean
function Dialog:isVisible()
	local feature = self.def.feature
	if not feature then
		return false
	end
	return Color.match(feature)
end

--- @param timeoutMs number|nil
--- @param intervalMs number|nil
--- @return boolean
function Dialog:waitAppear(timeoutMs, intervalMs)
	local feature = self.def.feature
	if not feature then
		Logger.warn(self.tag .. " waitAppear: feature 未配置")
		return false
	end
	return Color.waitMatch(feature, timeoutMs, intervalMs)
end

--- @param timeoutMs number|nil
--- @param intervalMs number|nil
--- @return boolean
function Dialog:waitGone(timeoutMs, intervalMs)
	local feature = self.def.feature
	if not feature then
		return true
	end
	return Color.waitGone(feature, timeoutMs, intervalMs)
end

--- @param delayMs number|nil
--- @return boolean
function Dialog:tapNeverAgain(delayMs)
	local btn = self.def.neverAgainBtn
	if not btn then
		return false
	end
	return performTap(btn, delayMs or 800)
end

--- @param delayMs number|nil
--- @return boolean
--- @return string|nil
function Dialog:tapConfirm(delayMs)
	return self:tap("confirm", delayMs)
end

--- @param delayMs number|nil
--- @return boolean
--- @return string|nil
function Dialog:tapCancel(delayMs)
	return self:tap("cancel", delayMs)
end

--- @param action string "confirm"|"cancel"|"neverAgain"
--- @param delayMs number|nil
--- @return boolean
--- @return string|nil
function Dialog:tap(action, delayMs)
	delayMs = delayMs or 800
	if action == "neverAgain" then
		if self:tapNeverAgain(delayMs) then
			return true
		end
		return false, "no_never_again_btn"
	end

	local btn
	local reason
	if action == "cancel" then
		btn = self.def.cancelBtn
		reason = "no_cancel_btn"
	else
		btn = self.def.confirmBtn
		reason = "no_confirm_btn"
	end

	if not btn then
		Logger.warn(self.tag .. " " .. reason .. " | " .. tostring(self.def.name or "未命名弹窗"))
		return false, reason
	end

	if not performTap(btn, delayMs) then
		return false, reason
	end
	return true
end

--- @param opts table|nil
--- @return boolean ok
--- @return string|nil reason
function Dialog:_tapAndWaitGone(opts)
	local name = self.def.name or "未命名弹窗"

	if opts.neverAgain then
		self:tapNeverAgain(opts.tapDelayMs)
	end

	local tapped, reason = self:tap(opts.action, opts.tapDelayMs)
	if not tapped then
		return false, reason
	end

	Logger.info(string.format("%s 已处理 [%s] action=%s", self.tag, name, opts.action))

	if opts.waitGoneMs == false or opts.waitGoneMs == 0 then
		return true
	end

	local goneMs = opts.waitGoneMs
	if goneMs == nil then
		if opts.mode == "flow" then
			goneMs = 3000
		else
			return true
		end
	end

	if self:waitGone(goneMs, opts.intervalMs) then
		return true
	end
	return false, "not_gone"
end

--- @param opts table|nil
--- @return boolean ok
--- @return string|nil reason
function Dialog:handle(opts)
	opts = mergeHandleOpts(opts)
	local name = self.def.name or "未命名弹窗"

	if opts.mode == "ifVisible" then
		if not self:isVisible() then
			return true
		end
		Logger.info(self.tag .. " [ifVisible] 命中 [" .. name .. "]")
		return self:_tapAndWaitGone(opts)
	end

	-- mode == "flow"
	if opts.waitAppearMs then
		if not self:waitAppear(opts.waitAppearMs, opts.intervalMs) then
			if opts.required then
				Logger.warn(self.tag .. " [flow] 等待超时 [" .. name .. "]")
				return false, "not_visible"
			end
			Logger.debug(self.tag .. " [flow] 未出现，跳过 [" .. name .. "]")
			return true, "skipped"
		end
	else
		if not self:isVisible() then
			return true
		end
	end

	Logger.info(self.tag .. " [flow] 处理 [" .. name .. "]")
	return self:_tapAndWaitGone(opts)
end

--- @param opts table|nil
--- @return function
function Dialog:toGuardHandler(opts)
	opts = mergeHandleOpts(opts, "ifVisible")
	return function()
		return self:handle(opts)
	end
end

--- 顺序确定的弹窗链；顺序未知请用 resolveUntilIdle，分支后续请用 resolveAfterPrimary
--- @param items table { { def, opts?, tag? }, ... }
--- @param defaultOpts table|nil
--- @return boolean ok
--- @return string|nil reason
function Dialog.handleChain(items, defaultOpts)
	defaultOpts = defaultOpts or {}
	for i, item in ipairs(items) do
		local itemOpts = mergeHandleOpts(defaultOpts)
		if item.opts then
			for k, v in pairs(item.opts) do
				itemOpts[k] = v
			end
		end

		local dialog = item.dialog
		if not dialog then
			dialog = Dialog.new(item.def, { tag = item.tag })
		end

		local ok, reason = dialog:handle(itemOpts)
		if not ok then
			return false, reason or ("chain_failed_" .. i)
		end
	end
	return true
end

--- 轮询消解顺序未知的 0~N 个弹窗（每轮按 priority 处理首个可见项，直到稳定空闲或超时）
--- @param candidates table
--- @param opts table|nil
--- @return boolean ok
--- @return table summary { handled, names, reason?, lastReason? }
function Dialog.resolveUntilIdle(candidates, opts)
	opts = opts or {}
	local timeoutMs = opts.timeoutMs or 8000
	local intervalMs = opts.intervalMs or 300
	local settleMs = opts.settleMs or 800
	local minWaitMs = opts.minWaitMs or 500
	local maxHandled = opts.maxHandled
	local tag = opts.tag or DEFAULT_TAG

	local prepared = {}
	for i, item in ipairs(candidates or {}) do
		local dialog = ensureDialog(item, item.tag or tag)
		prepared[i] = {
			dialog = dialog,
			opts = mergeHandleOpts(item.opts, "ifVisible"),
			priority = item.priority or 0,
			name = item.name or dialog.def.name or ("candidate_" .. i),
			when = item.when,
		}
	end
	local sorted = sortByPriority(prepared)

	local startMs = nowMs()
	local lastVisibleAt = startMs
	local handled = 0
	local names = {}
	local lastReason = nil

	while nowMs() < startMs + timeoutMs do
		Guard.sleep(intervalMs, intervalMs)

		local hit = findFirstVisibleCandidate(sorted)
		if hit then
			lastVisibleAt = nowMs()
			local ok, reason = hit.dialog:handle(hit.opts)
			lastReason = reason
			if not ok then
				Logger.warn(tag .. " resolveUntilIdle 失败 [" .. hit.name .. "] | " .. tostring(reason))
				return false, {
					handled = handled,
					names = names,
					reason = reason,
					lastReason = lastReason,
				}
			end
			handled = handled + 1
			names[#names + 1] = hit.name
			Logger.info(tag .. " resolveUntilIdle 已处理 [" .. hit.name .. "] " .. handled .. "/" .. tostring(maxHandled or "∞"))
			if maxHandled and handled >= maxHandled then
				break
			end
		else
			local elapsed = nowMs() - startMs
			local idleFor = nowMs() - lastVisibleAt
			if elapsed >= minWaitMs and idleFor >= settleMs then
				break
			end
		end
	end

	if handled == 0 then
		Logger.debug(tag .. " resolveUntilIdle 无弹窗")
	else
		Logger.info(tag .. " resolveUntilIdle 完成 handled=" .. handled)
	end
	return true, {
		handled = handled,
		names = names,
		lastReason = lastReason,
	}
end

--- 先处理主弹窗 flow，再轮询 watch 分支或 successWhen 成功条件
--- @param cfg table
--- @return boolean ok
--- @return string outcome
--- @return string|nil reason
function Dialog.resolveAfterPrimary(cfg)
	cfg = cfg or {}
	local tag = cfg.tag or DEFAULT_TAG
	local timeoutMs = cfg.timeoutMs or 5000
	local intervalMs = cfg.intervalMs or 300
	local successResult = cfg.successResult or "ok"

	local primaryItem = cfg.primary or {}
	local primaryDialog = ensureDialog(primaryItem, tag)
	local primaryOpts = mergeHandleOpts(primaryItem.opts, "flow")

	local ok, reason = primaryDialog:handle(primaryOpts)
	if not ok then
		Logger.warn(tag .. " resolveAfterPrimary 主弹窗失败 | " .. tostring(reason))
		return false, "failed", reason
	end

	local watchList = {}
	for i, w in ipairs(cfg.watch or {}) do
		watchList[i] = {
			dialog = ensureDialog(w, tag),
			opts = mergeHandleOpts(w.opts, "ifVisible"),
			result = w.result or ("watch_" .. i),
			after = w.after,
		}
	end

	local deadline = nowMs() + timeoutMs
	while nowMs() < deadline do
		for _, w in ipairs(watchList) do
			if w.dialog:isVisible() then
				local wok, wreason = w.dialog:handle(w.opts)
				if not wok then
					Logger.warn(tag .. " resolveAfterPrimary watch 失败 | " .. tostring(wreason))
					return false, "failed", wreason
				end
				if w.after then
					w.after()
				end
				return true, w.result
			end
		end

		if cfg.successWhen and cfg.successWhen() then
			return true, successResult
		end

		local anyWatchVisible = false
		for _, w in ipairs(watchList) do
			if w.dialog:isVisible() then
				anyWatchVisible = true
				break
			end
		end
		if not primaryDialog:isVisible() and not anyWatchVisible then
			return true, successResult
		end

		Guard.sleep(intervalMs, intervalMs)
	end

	Logger.warn(tag .. " resolveAfterPrimary 轮询超时")
	return false, "failed", "timeout"
end

return Dialog
