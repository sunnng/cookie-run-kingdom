--[[
模块: 日志
路径: lib.logger
功能: print + 写入 data/run.log（带轮转，防止文件无限增长）
依赖: lib.paths
--]]

local Paths = require("lib.paths")

local Logger = {}
--- 日志级别：1=ERROR 2=WARN 3=INFO(默认) 4=DEBUG
--- 设为 4 可输出 DEBUG 级别的高频轮询日志（调试用）
Logger.level = 3

-- 轮转默认参数（可由 config.LOG 覆盖）
local ROTATE_BYTES = 1048576      -- 1 MB 触发轮转
local KEEP_TAIL_BYTES = 262144    -- 轮转后保留最近 256 KB

--- 应用 config.LOG 覆盖（若提供）
--- @param logStatic table|nil
local function applyConfig(logStatic)
	if type(logStatic) == "table" then
		if type(logStatic.rotateBytes) == "number" and logStatic.rotateBytes > 0 then
			ROTATE_BYTES = logStatic.rotateBytes
		end
		if type(logStatic.keepTailBytes) == "number" and logStatic.keepTailBytes >= 0 then
			KEEP_TAIL_BYTES = logStatic.keepTailBytes
		end
	end
end

--- 启动时配置轮转参数（可选，由 ui.app 调用）
--- @param logStatic table|nil
function Logger.configure(logStatic)
	applyConfig(logStatic)
end

--- 读取文件尾部（保留最近日志）
--- @param path string
--- @param tailBytes number
--- @return string
local function readTail(path, tailBytes)
	local f = io.open(path, "rb")
	if not f then
		return ""
	end
	local size = f:seek("end")
	if size <= tailBytes then
		f:seek("set")
		local content = f:read("*a") or ""
		f:close()
		return content
	end
	-- 定位到尾部，向前回退到一个完整行的起点，避免截断半行
	local start = size - tailBytes
	f:seek("set", start)
	local content = f:read("*a") or ""
	f:close()
	local nl = content:find("\n")
	if nl then
		content = content:sub(nl + 1)
	end
	return content
end

--- 超过阈值时轮转：保留尾部，覆盖写回
local function rotateIfNeeded(path)
	local size = fileSize(path)
	if not size or size < ROTATE_BYTES then
		return
	end
	local tail = readTail(path, KEEP_TAIL_BYTES)
	writeFile(path, tail) -- 覆盖写，等效于 "truncate + rewrite"
end

local function appendLog(line)
	Paths.ensureDataDir()
	local path = Paths.getLogPath()
	rotateIfNeeded(path)
	local f = io.open(path, "a")
	if f then
		f:write(line .. "\n")
		f:close()
	end
end

local function log(level, tag, msg)
	if level > Logger.level then
		return
	end
	local info = debug.getinfo(3, "Sl")
	local file = info and (info.source or "?"):gsub("^@", ""):match("[^/\\]+$") or "?"
	local lineNum = info and info.currentline or 0
	local logLine = string.format("%s [%s:%d] [%s] %s", os.date("%m-%d %H:%M:%S"), file, lineNum, tag, tostring(msg))
	print(logLine)
	appendLog(logLine)
end

function Logger.error(msg) log(1, "ERROR", msg) end
function Logger.warn(msg)  log(2, "WARN",  msg) end
function Logger.info(msg)  log(3, "INFO",  msg) end
function Logger.debug(msg) log(4, "DEBUG", msg) end

return Logger
