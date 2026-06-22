--[[
模块: 状态机
路径: core.state
功能: 极简状态机，实例隔离
--]]

local State = {}

function State.new()
	local sm = {
		current = nil ,
		retries = 0 ,
		maxRetry = 3 ,
		startTime = 0 ,
		timeout = 300 ,
	}
	
	setmetatable(sm , { __index = State })
	return sm
end

function State.init(self , firstState , opts)
	opts = opts or {}
	self.current = firstState
	self.retries = 0
	self.maxRetry = opts.maxRetry or 3
	self.timeout = opts.timeout or 300
	self.startTime = os.time()
end

function State.to(self , state)
	self.current = state
	self.retries = 0
end

function State.retry(self)
	self.retries = self.retries + 1
	if self.retries > self.maxRetry then
		return false , string.format("状态 [%s] 重试超限 (%d/%d)" , self.current , self.retries , self.maxRetry)
	end
	return true , string.format("重试 %d/%d" , self.retries , self.maxRetry)
end

function State.isTimeout(self)
	return (os.time() - self.startTime) > self.timeout
end

function State.get(self)
	return self.current
end

return State
