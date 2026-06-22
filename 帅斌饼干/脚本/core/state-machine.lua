--[[
模块: 状态机
路径: core.state-machine
功能: 极简状态机，实例隔离，内置状态机运行函数 runner
--]]

local Logger = require("lib.logger")

local StateMachine = {}

local TAG = "[StateMachine]"

StateMachine.KEEP = "__keep__" -- 保持当前状态（等待 / 多步未完成）
StateMachine.RETRY = "__retry__" -- 当前状态重试一次（仅显式返回时计数）
StateMachine.DONE = "__done__" -- 正常结束

function StateMachine.new()
	local sm = {
		current = nil ,
		--- 主动重试（仅 handler 显式返回 RETRY）
		retries = 0 ,
		maxRetry = 3 ,
		--- 异常重试（handler pcall 失败）
		errors = 0 ,
		maxError = 3 ,
		--- 重试退避毫秒（RETRY/异常重试后 sleep；>0 时替代本轮 interval，=0 时用 interval）
		retryIntervalMs = 0 ,
		startTime = 0 ,
		timeout = 1800 ,
		--- 调试：累计轮次
		_ticks = 0 ,
	}
	setmetatable(sm , { __index = StateMachine })
	return sm
end

function StateMachine.init(self , firstState , opts)
	opts = opts or {}
	self.current = firstState
	self.retries = 0
	self.errors = 0
	self.maxRetry = opts.maxRetry or 3
	self.maxError = opts.maxError or 3
	self.retryIntervalMs = opts.retryIntervalMs or 0
	self.timeout = opts.timeout or 1800
	self.startTime = os.time()
	self._ticks = 0
end

function StateMachine.to(self , state)
	self.current = state
	self.retries = 0
	self.errors = 0
end

--- 主动重试计数（handler 显式返回 RETRY 时调用）
--- maxRetry 表示额外重试次数，共最多 maxRetry + 1 次执行
--- @return boolean ok
--- @return string msg
function StateMachine.retryActive(self)
	self.retries = self.retries + 1
	if self.retries > self.maxRetry then
		return false , string.format("状态 [%s] 主动重试超限 (%d/%d)" , self.current , self.retries , self.maxRetry)
	end
	return true , string.format("主动重试 %d/%d" , self.retries , self.maxRetry)
end

--- 异常重试计数（handler pcall 失败时调用）
--- @return boolean ok
--- @return string msg
function StateMachine.retryError(self)
	self.errors = self.errors + 1
	if self.errors > self.maxError then
		return false , string.format("状态 [%s] 异常重试超限 (%d/%d)" , self.current , self.errors , self.maxError)
	end
	return true , string.format("异常重试 %d/%d" , self.errors , self.maxError)
end

--- 向后兼容：retry() = retryActive()
function StateMachine.retry(self)
	return self:retryActive()
end

function StateMachine.isTimeout(self)
	return (os.time() - self.startTime) > self.timeout
end

function StateMachine.getState(self)
	return self.current
end

--- 运行状态机（内置 runner）
--- @param handlers table { stateName = function(sm) return nextState|symbol end }
---   返回约定:
---     "next_state"  -> 切换到该状态（重试计数清零）
---     "__retry__"     -> 当前状态重试，retries += 1
---     "__keep__"      -> 保持当前状态，不计重试
---     nil             -> 同 KEEP（打 debug 日志）
---     "__done__"      -> 正常结束
---     false, "msg"    -> 致命错误，终止
--- @param opts table|nil { interval=500, guard=function() end, label=string }
---   interval: 正常轮询 sleep 毫秒（KEEP / 切态后）
---   guard:    每轮 handler 前 + loopSleep 分片前调用（如 Guard.check）
---   label:    日志前缀（如「矿山勘查」）
--- init 选项 retryIntervalMs: RETRY/异常重试后的 sleep；>0 时用该值且不再叠加 interval
--- @return boolean ok
--- @return string|nil err
function StateMachine.run(self , handlers , opts)
	opts = opts or {}
	local interval = opts.interval or 500
	local label = opts.label or "任务"

	Logger.info(string.format(
		TAG .. " [%s] 启动 初始=%s maxRetry=%d timeout=%ds interval=%dms retryWait=%dms" ,
		label , tostring(self.current) , self.maxRetry , self.timeout ,
		interval , self.retryIntervalMs
	))

	local function loopSleep(ms)
		ms = ms or interval
		if not opts.guard then
			sleep(ms)
			return
		end
		local left = ms
		while left > 0 do
			pcall(opts.guard)
			local chunk = math.min(left, interval)
			sleep(chunk)
			left = left - chunk
		end
	end

	while true do
		self._ticks = self._ticks + 1

		if self:isTimeout() then
			local elapsed = os.time() - self.startTime
			Logger.warn(string.format(
				TAG .. " [%s] 超时 状态=%s 轮次=%d 耗时=%ds" ,
				label , self.current , self._ticks , elapsed
			))
			return false , "timeout"
		end

		if opts.guard then
			pcall(opts.guard)
		end

		local state = self:getState()
		local handler = handlers[state]
		if not handler then
			Logger.warn(TAG .. " [" .. label .. "] 未知状态: " .. tostring(state))
			return false , "unknown state: " .. tostring(state)
		end

		Logger.debug(string.format(
			TAG .. " [%s] [tick#%d] 状态=%s retry=%d err=%d" ,
			label , self._ticks , state , self.retries , self.errors
		))

		local ok , ret , msg = pcall(handler , self)
		local retried = false

		if not ok then
			local rok , rmsg = self:retryError()
			if not rok then
				Logger.warn(TAG .. " [" .. label .. "] " .. rmsg .. " | " .. tostring(ret))
				return false , rmsg .. " | error: " .. tostring(ret)
			end
			Logger.info(TAG .. " [" .. label .. "] [" .. state .. "] " .. rmsg)
			retried = true
		elseif ret == false then
			Logger.warn(TAG .. " [" .. label .. "] [" .. state .. "] 致命: " .. tostring(msg))
			return false , msg or "fatal in state " .. state
		elseif ret == StateMachine.DONE then
			Logger.info(string.format(
				TAG .. " [%s] 正常结束 末状态=%s 轮次=%d 耗时=%ds" ,
				label , state , self._ticks , os.time() - self.startTime
			))
			return true
		elseif ret == StateMachine.KEEP or ret == nil then
			if ret == nil then
				Logger.debug(TAG .. " [" .. label .. "] [" .. state .. "] 未返回值→KEEP")
			end
		elseif ret == StateMachine.RETRY then
			local rok , rmsg = self:retryActive()
			if not rok then
				Logger.warn(TAG .. " [" .. label .. "] " .. rmsg)
				return false , rmsg
			end
			Logger.info(TAG .. " [" .. label .. "] [" .. state .. "] " .. rmsg)
			retried = true
		elseif type(ret) == "string" then
			Logger.info(TAG .. " [" .. label .. "] [" .. state .. "] → " .. ret)
			self:to(ret)
		else
			Logger.warn(TAG .. " [" .. label .. "] [" .. state .. "] 非法返回值 " .. tostring(ret) .. "→KEEP")
		end

		if retried then
			loopSleep(self.retryIntervalMs > 0 and self.retryIntervalMs or interval)
		else
			loopSleep(interval)
		end
	end
end

return StateMachine
