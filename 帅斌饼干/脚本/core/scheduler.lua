--[[
模块: 任务调度
路径: core.scheduler
功能: 条件任务串行执行，返回本轮是否有任务
依赖: lib.logger
--]]

local Logger = require("lib.logger")
local StatusHud = require("lib.status-hud")

local Scheduler = {}
local tasks = {}

local TAG = "[Scheduler]"

function Scheduler.add(name , condition , action)
	tasks[#tasks + 1] = { name = name , condition = condition , action = action }
	Logger.debug(TAG .. " 注册任务: " .. name)
end

function Scheduler.clear()
	if #tasks > 0 then
		Logger.debug(TAG .. " 清空 " .. #tasks .. " 个任务")
	end
	tasks = {}
end

--- @return number
function Scheduler.count()
	return #tasks
end

--- 执行一轮
--- @param stopOnError boolean
--- @return boolean hasWork 本轮是否有任务执行
--- @return boolean ok      是否成功完成（stopOnError时遇错返回false）
function Scheduler.run(stopOnError)
	local hasWork = false
	local ran = 0
	local skipped = {}

	for _ , task in ipairs(tasks) do
		local condOk , condResult = pcall(task.condition)
		if not condOk then
			Logger.warn(TAG .. " [条件] " .. task.name .. " 异常: " .. tostring(condResult))
		elseif condResult then
			hasWork = true
			ran = ran + 1
			StatusHud.setTask(task.name , "…")
			Logger.info(TAG .. " [执行] " .. task.name .. " 开始")

			local t0 = os.clock()
			local ok , err = pcall(task.action)
			local elapsed = os.clock() - t0

			if not ok then
				Logger.error(string.format(
					TAG .. " [执行] %s 异常 (%.1fs) | %s" ,
					task.name , elapsed , tostring(err)
				))
				if stopOnError then
					return hasWork , false
				end
			else
				if err == false then
					Logger.warn(string.format(
						TAG .. " [执行] %s 结束 false (%.1fs)" ,
						task.name , elapsed
					))
				else
					Logger.info(string.format(
						TAG .. " [执行] %s 完成 (%.1fs)" ,
						task.name , elapsed
					))
				end
			end
		else
			skipped[#skipped + 1] = task.name
		end
	end

	if ran == 0 then
		Logger.debug(TAG .. " [轮次] 无任务执行" .. (#skipped > 0 and (" (跳过:" .. table.concat(skipped , "、") .. ")") or ""))
	else
		Logger.debug(TAG .. " [轮次] 执行 " .. ran .. " 个任务")
	end

	return hasWork , true
end

return Scheduler
