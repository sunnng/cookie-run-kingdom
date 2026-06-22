--[[
模块: OCR 工具
路径: lib.ocr
依赖: TomatoOCR.apk, LuaEngine, config
设备: 1600×900 @ 320dpi
--]]

import("com.nx.assist.lua.LuaEngine")

local Config = require("config")
local Logger = require("lib.logger")
local ENGINE = Config.ocrStatic().ENGINE
local TIMING = Config.ocrStatic().TIMING

local Ocr = {}
local engine = nil
local warnedNotReady = false  -- engine 未就绪告警标志（只 warn 一次，避免刷屏）

local function validRect(rect)
	return type(rect) == "table"
		and type(rect[1]) == "number"
		and type(rect[2]) == "number"
		and type(rect[3]) == "number"
		and type(rect[4]) == "number"
		and rect[3] > rect[1]
		and rect[4] > rect[2]
end

--- 应用 config.ENGINE 到 Tomato 引擎（init 时一次）
local function applyEngine()
	local e = ENGINE
	engine.setRecType(e.REC_TYPE)
	engine.setDetBoxType(e.DET_BOX)
	engine.setDetScaleRatio(e.DET_SCALE)
	engine.setDetUnclipRatio(e.DET_UNCLIP)
	engine.setRecScoreThreshold(e.REC_SCORE)
	engine.setRunMode(e.RUN_MODE)
	engine.setFilterColor(e.FILTER_COLOR, e.FILTER_MODE)
	if e.BINARY_THRESH and e.BINARY_THRESH > 0 then
		engine.setBinaryThresh(e.BINARY_THRESH)
	else
		engine.setBinaryThresh(0)
	end
end

--- 初始化 TomatoOCR
--- @param license string|nil "apiSecret|productSecret"，nil 时读 config
--- @param remark string|nil 备注
--- @return boolean ok
function Ocr.init(license, remark)
	if engine then
		return true
	end
	local cfg = Config.ocrStatic()
	license = license or cfg.LICENSE
	remark = remark or cfg.REMARK or ""
	local ok, err = pcall(function()
		local loader = LuaEngine.loadApk("TomatoOCR.apk")
		if not loader then
			error("TomatoOCR.apk 未找到，请将插件加入 .rc")
		end
		local cls = loader.loadClass("com.tomato.ocr.lr.OCRApi")
		engine = cls.init(LuaEngine.getContext())
		local flag = engine.setLicense(license, remark)
		Logger.info("[OCR] License=" .. tostring(flag))
		applyEngine()
	end)
	if not ok then
		Logger.error("[OCR] 初始化失败: " .. tostring(err))
		engine = nil
		return false
	end
	warnedNotReady = false
	return true
end

--- 解析 JSON 结果
local function decode(str)
	if not str or str == "" then
		return nil
	end
	local ok, t = pcall(jsonLib.decode, str)
	if ok and type(t) == "table" then
		return t
	end
	return nil
end

--- location 局部中心（四角或扁平框）
local function localCenter(loc)
	if type(loc) ~= "table" then
		return nil
	end
	if type(loc[1]) == "table" then
		local minX, maxX, minY, maxY
		for _, pt in ipairs(loc) do
			local px, py = pt[1], pt[2]
			if px and py then
				minX = minX and math.min(minX, px) or px
				maxX = maxX and math.max(maxX, px) or px
				minY = minY and math.min(minY, py) or py
				maxY = maxY and math.max(maxY, py) or py
			end
		end
		if minX then
			return (minX + maxX) / 2, (minY + maxY) / 2
		end
		return nil
	end
	if type(loc[1]) == "number" and type(loc[4]) == "number" then
		return (loc[1] + loc[3]) / 2, (loc[2] + loc[4]) / 2
	end
	return nil
end

local function findInItems(items, text, x1, y1)
	for _, item in ipairs(items or {}) do
		local w = item.words or ""
		if w ~= "" and w:find(text, 1, true) then
			local lx, ly = localCenter(item.location)
			if lx and ly and lx >= 0 and ly >= 0 then
				return lx + x1, ly + y1
			end
		end
	end
	return nil
end

--- 找文字坐标（依赖最近一次 scan；items 作 findTapPoint 失败时的回退）
local function findPoint(text, x1, y1, items)
	local pt = engine.findTapPoint(text)
	if pt and pt ~= "" and pt ~= "[-1,-1]" then
		local t = decode(pt)
		if t and t[1] and t[2] and t[1] >= 0 and t[2] >= 0 then
			return t[1] + x1, t[2] + y1
		end
	end
	return findInItems(items, text, x1, y1)
end

--- 截图并识别
--- @param rect table {x1,y1,x2,y2}
--- @param mode number|nil 2=单行, 3=多行；nil 时用 ENGINE.MULTI_MODE
--- @param returnType string|nil "json"|"text"|"num" 或字符集；nil 时用 ENGINE.RETURN_TYPE
--- @return table|nil {raw, text, items, x1, y1}
function Ocr.scan(rect, mode, returnType)
	if not engine then
		if not warnedNotReady then
			Logger.warn("[OCR] 引擎未初始化，Ocr.scan 返回 nil（此告警仅一次）。请检查 Ocr.init 是否被调用或失败。")
			warnedNotReady = true
		end
		return nil
	end
	if not validRect(rect) then
		Logger.warn("[OCR] 无效 rect: " .. tostring(rect))
		return nil
	end
	mode = mode or ENGINE.MULTI_MODE
	returnType = returnType or ENGINE.RETURN_TYPE

	local useNumberRec = (returnType == "num")
	if useNumberRec then
		engine.setRecType("number")
	end
	engine.setReturnType(returnType)

	local okSnap, bmp = pcall(LuaEngine.snapShot, rect[1], rect[2], rect[3], rect[4])
	if not okSnap or not bmp then
		if useNumberRec then
			engine.setRecType(ENGINE.REC_TYPE)
		end
		Logger.warn("[OCR] 截图失败: " .. tostring(bmp))
		return nil
	end

	local okOcr, raw = pcall(function()
		return engine.ocrBitmap(bmp, mode)
	end)
	pcall(function() bmp.recycle() end)
	if useNumberRec then
		engine.setRecType(ENGINE.REC_TYPE)
	end
	if not okOcr then
		Logger.warn("[OCR] 识别异常: " .. tostring(raw))
		return nil
	end

	if not raw or raw == "" then
		return nil
	end

	local result = { raw = raw, text = "", items = {}, x1 = rect[1], y1 = rect[2] }

	if returnType == "text" then
		result.text = raw
	elseif returnType == "num" then
		result.text = tonumber(raw) or raw
	elseif returnType == "json" then
		local data = decode(raw)
		if not data then
			return result
		end
		if type(data) == "table" and data.words then
			result.items = { data }
			result.text = data.words
		elseif type(data) == "table" then
			result.items = data
			local parts = {}
			for _, v in ipairs(data) do
				if v.words then
					parts[#parts + 1] = v.words
				end
			end
			result.text = table.concat(parts, "")
		end
	else
		result.text = raw
	end

	return result
end

--- 识别单行文字
function Ocr.text(rect, returnType)
	local r = Ocr.scan(rect, ENGINE.LINE_MODE, returnType or "text")
	return r and r.text or ""
end

--- 识别数字
function Ocr.number(rect)
	local r = Ocr.scan(rect, ENGINE.LINE_MODE, "num")
	return r and tonumber(r.text) or nil
end

--- 从 OCR 文本解析 x/x（左=当前，右=上限）
--- @param text string|nil
--- @return number|nil current
--- @return number|nil max
function Ocr.parseFraction(text)
	if not text or text == "" then
		return nil, nil
	end
	text = text:gsub("%s+", "")
	text = text:gsub(",", "")
	text = text:gsub("，", "")
	local cur, max = text:match("^(%d+)/(%d+)$")
		or text:match("(%d+)/(%d+)")
	if cur and max then
		return tonumber(cur), tonumber(max)
	end
	return nil, nil
end

--- 识别 x/x 区域（左=当前，右=上限）
--- @param rect table {x1,y1,x2,y2}
--- @return number|nil current
--- @return number|nil max
--- @return string|nil raw 原始 OCR 文本（调试）
function Ocr.fraction(rect)
	if not validRect(rect) then
		Logger.warn("[OCR] fraction 无效 rect")
		return nil, nil, nil
	end

	local text = Ocr.text(rect, "text")
	if text and text ~= "" then
		local cur, max = Ocr.parseFraction(text)
		if cur ~= nil and max ~= nil then
			return cur, max, text
		end
	end

	-- 兜底：以区域中线分左右，分别识数字（slash 漏识时）
	local mid = math.floor((rect[1] + rect[3]) / 2)
	local cur = Ocr.number({ rect[1], rect[2], mid, rect[4] })
	local max = Ocr.number({ mid, rect[2], rect[3], rect[4] })
	if cur ~= nil and max ~= nil then
		return cur, max, string.format("%d/%d", cur, max)
	end

	if text and text ~= "" then
		Logger.debug("[OCR] fraction 解析失败: " .. text)
	end
	return nil, nil, text
end

--- 区域内是否包含文字
function Ocr.has(text, rect)
	if not text or text == "" then
		return false
	end
	local r = Ocr.scan(rect, ENGINE.MULTI_MODE, "json")
	if not r then
		return false
	end
	if r.raw and r.raw:find(text, 1, true) then
		return true
	end
	if r.text:find(text, 1, true) then
		return true
	end
	for _, item in ipairs(r.items) do
		local w = item.words or ""
		if w:find(text, 1, true) then
			return true
		end
	end
	return false
end

--- 识别并点击文字
function Ocr.tap(text, rect, delayMs)
	local r = Ocr.scan(rect, ENGINE.MULTI_MODE, "json")
	if not r then
		return false
	end
	local x, y = findPoint(text, r.x1, r.y1, r.items)
	if not x then
		return false
	end
	tap(x, y)
	if delayMs then
		sleep(delayMs)
	end
	return true
end

--- 识别并返回文字坐标
function Ocr.find(text, rect)
	local r = Ocr.scan(rect, ENGINE.MULTI_MODE, "json")
	if not r then
		return nil
	end
	return findPoint(text, r.x1, r.y1, r.items)
end

--- 轮询等待文字出现
function Ocr.wait(text, rect, timeoutMs, intervalMs)
	timeoutMs = timeoutMs or 10000
	intervalMs = intervalMs or TIMING.POLL_INTERVAL_MS
	local deadline = tickCount() + timeoutMs
	while tickCount() < deadline do
		if Ocr.has(text, rect) then
			return true
		end
		sleep(intervalMs)
	end
	return false
end

--- 释放引擎（脚本退出时可选调用）
function Ocr.release()
	if engine and engine.release then
		pcall(function() engine.release() end)
	end
	engine = nil
end

return Ocr
