--[[
模块: 运行时
路径: core.runtime
功能: 脚本永久运行引擎：清理 → 注册 → 主线程调度 + 守卫
依赖: core.scheduler, core.guard, lib.logger, lib.color, config
--]]

local Scheduler = require("core.scheduler")
local Guard = require("core.guard")
local Color = require("lib.color")
local Logger = require("lib.logger")
local StatusHud = require("lib.status-hud")
local UserConfig = require("lib.user-config")
local Config = require("config")
local Session = require("game.常规_未知的地底矿山.模块_矿山勘查.勘查_会话")
local MiningSession = require("game.常规_未知的地底矿山.模块_矿山开采.开采_会话")
local SeasideMarketSession = require("game.常规_海滩交易所.交易所_会话")
local ArenaSession = require("game.常规_王国竞技场.竞技场_会话")

local Runtime = {}

local TAG = "[Runtime]"

--- 业务注入点，由 game.register 赋值
Runtime.register = function()
	Logger.warn(TAG .. " 未注入 register，业务为空")
end

local function clearAll()
	Scheduler.clear()
	Guard.clear()
end

--- 永久运行（imgui 关闭后调用）
function Runtime.run()
	clearAll()
	StatusHud.init()
	StatusHud.set("run" , "运行中")
	Runtime.register()
	
	local rt = Config.runtimeConfig()
	local guardStep = rt.GUARD_INTERVAL_MS or 500
	local idleMs = rt.IDLE_DELAY_MS or 30000
	local stepMs = rt.STEP_DELAY_MS or 5000
	
	Color.setGuardHook(Guard.check)
	
	Logger.info(string.format(
	TAG .. " 启动 | 守卫分片:%dms idle:%ds step:%ds stopOnError:%s" ,
	guardStep , math.floor(idleMs / 1000) , math.floor(stepMs / 1000) ,
	tostring(rt.STOP_ON_ERROR)
	))
	
	local round = 0
	while true do
		round = round + 1
		Logger.debug(TAG .. " [轮次] #" .. round .. " 开始")
		
		Guard.check()
		local hasWork , ok = Scheduler.run(rt.STOP_ON_ERROR)
		
		if not ok then
			Logger.warn(TAG .. " [轮次] #" .. round .. " 调度异常终止")
			return
		end
		
		if not hasWork then
			local mineCfg = UserConfig.get("mine")
			local marketCfg = UserConfig.get("seasideMarket")
			local arenaCfg = UserConfig.get("arena")
			local farRemain = mineCfg.surveyEnabled and Session.restoreProgress() or 0
			local miningRemain = mineCfg.miningEnabled and MiningSession.restoreProgress() or 0
			local marketRemain = marketCfg and marketCfg.enabled and SeasideMarketSession.restoreProgress() or 0
			local arenaRemain = arenaCfg and arenaCfg.enabled and ArenaSession.getTimeUntilRefresh() or 0
			local waitRemain = math.max(farRemain , miningRemain , marketRemain , arenaRemain)
			if waitRemain > 0 then
				local idleSec = math.max(1 , math.floor(idleMs / 1000))
				Logger.info(string.format(
				TAG .. " [idle] 等待 剩余%ds（勘查%d 开采%d 海滩%d 竞技场%d）本轮tick %ds" ,
				waitRemain , farRemain , miningRemain , marketRemain , arenaRemain , idleSec
				))
				for _ = 1 , idleSec do
					farRemain = mineCfg.surveyEnabled and Session.restoreProgress() or 0
					miningRemain = mineCfg.miningEnabled and MiningSession.restoreProgress() or 0
					marketRemain = marketCfg and marketCfg.enabled and SeasideMarketSession.restoreProgress() or 0
					arenaRemain = arenaCfg and arenaCfg.enabled and ArenaSession.getTimeUntilRefresh() or 0
					waitRemain = math.max(farRemain , miningRemain , marketRemain , arenaRemain)
					if waitRemain <= 0 then
						Logger.info(TAG .. " [idle] 等待已到期")
						break
					end
					StatusHud.setMineWait({
						surveySec = farRemain > 0 and farRemain or nil ,
						miningSec = miningRemain > 0 and miningRemain or nil ,
						marketSec = marketRemain > 0 and marketRemain or nil ,
						target = mineCfg.targetFloor ,
						extra = arenaRemain > 0 and ("竞技场 " .. arenaRemain .. "s") or "挂机中" ,
					})
					Guard.sleep(1000 , guardStep)
				end
			else
				StatusHud.setIdle()
				Logger.info(TAG .. " [idle] 无任务 挂机 " .. math.floor(idleMs / 1000) .. "s")
				Guard.sleep(idleMs , guardStep)
			end
		else
			Logger.debug(TAG .. " [step] 轮间等待 " .. math.floor(stepMs / 1000) .. "s")
			Guard.sleep(stepMs , guardStep)
		end
	end
end

return Runtime
