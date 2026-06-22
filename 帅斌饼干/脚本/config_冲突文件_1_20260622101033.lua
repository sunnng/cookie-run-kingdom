--[[
模块: 配置入口
路径: config
功能: static（打包常量）唯一数据源
--]]

--- 打包常量（改后需重新打包）
local STATIC = {
	DISPLAY = {
		WIDTH = 1600 ,
		HEIGHT = 900 ,
	} ,
	-- 顶部状态 HUD（lib.status-hud）
	HUD = {
		enabled = true ,
		size = 10 ,
		color = "0xffff9100" ,
		bg = "0x66001428" , -- 60% 透明（alpha 40%）
		pos = 0 ,
		x = 0 ,
		y = 0 ,
		width = 1600 ,
		height = 32 ,
		pl = 20 ,
		pt = 3 ,
		pr = 20 ,
		pb = 3 ,
		align_text = 1 ,
	} ,
	-- 远端 update.txt 示例: { "version": "0.0.2", "MD5": "...", "msg": "更新说明" }
	HOT_UPDATE = {
		ENABLED = true ,
		BASE_URL = "http://101.35.246.76:7011/usr/pubg-account/yuan" ,
		INFO_FILE = "update.txt" ,
		PACKAGE_FILE = "sb.lrj" ,
		VERSION = "0.0.10" ,
		VERIFY_MD5 = false ,
		DOWNLOAD_DIR = "/sdcard/Download/" ,
		COUNTDOWN_SEC = 3 ,
		SLOGAN = "帅斌饼干" ,
		TIMEOUT_SEC = 30 ,
		TOAST_ON_ERROR = true ,
	} ,
	-- 百宝云卡密（lib.license）
	LICENSE = {
		API_HOST = "http://get.91shenfan.com/api" ,
		TOKEN = "a3995fddc20a805e6b83cf97c1a77478" ,
		PROJECT_NAME = "测试项目" ,
		UNBIND_PASSWORD = "123456" ,
		HEARTBEAT_INTERVAL = 600 ,
	} ,
	-- TomatoOCR（lib.ocr）
	OCR = {
		LICENSE = "WNPUFLZ0MN3BYVOG2WBPOXD8GVKB7IOL|8Wb1QN63dgepIeXngwzbBH3g" ,
		REMARK = "" ,
		ENGINE = {
			REC_TYPE = "ch-3.0" ,
			REC_SCORE = 0.3 ,
			RUN_MODE = "slow" ,
			DET_BOX = "rect" ,
			DET_UNCLIP = 1.9 ,
			DET_SCALE = 1.0 ,
			RETURN_TYPE = "json" ,
			MULTI_MODE = 3 , -- 多行/找点
			LINE_MODE = 2 , -- 单行
			FILTER_COLOR = "" ,
			FILTER_MODE = "black" ,
			BINARY_THRESH = 0 ,
		} ,
		TIMING = {
			POLL_INTERVAL_MS = 1000 ,
		} ,
	} ,
	-- 主循环（core.runtime）
	RUNTIME = {
		GUARD_INTERVAL_MS = 500 , -- 主线程守卫分片间隔（wait/sleep/状态机轮询）
		GUARD_SLEEP_MS = 1000 , -- 保留字段（旧守卫线程用，现未使用）
		STOP_ON_ERROR = false , -- 调度遇错是否停止
		STEP_DELAY_MS = 5000 , -- 有任务时轮间间隔（5秒）
		IDLE_DELAY_MS = 30000 , -- 没任务时挂机间隔（30秒）
	} ,
	-- 用户配置默认值（运行时结构，持久化覆盖见 lib.user-config）
	USER = {
		mine = {
			surveyEnabled = true ,
			miningEnabled = false ,
			targetFloor = 6 ,
			farGap = 2 ,
			ocrPollSec = 60 ,
			farWaitSec = 600 ,
			-- 开采选卡优先级（键名同矿山_特征库.oreVeinCards）
			miningIntervalSec = 1200 , -- 开采完成后再次调度间隔（20分钟）
			miningOreCards = {
				"amberFossil" ,
				"sugarOre" ,
				"purpleFossil" ,
				"emeraldFossil" ,
				"flourStone" ,
			} ,
		} ,
		biscuit = {
			enabled = false ,
			maxRolls = 500 ,
			targets = {
				{ enabled = true , name = "冷却时间" , minPercent = 5 } ,
				{ enabled = true , name = "会心" , minPercent = 6 } ,
				{ enabled = false , name = "" , minPercent = 0 } ,
				{ enabled = false , name = "" , minPercent = 0 } ,
			} ,
			-- 总和规则（可选）：2条攻击力，取最高2条且加和≥11，也算毕业
			sumRules = {
				{ enabled = true , name = "攻击力" , count = 2 , minSum = 11 } ,
				-- { enabled = true, name = "生命值", count = 2, minSum = 15 },
			}
		} ,
		square = {
			enabled = true ,
			dailyCap = 240 ,
			checkIntervalSec = 60 ,
			chunkSec = 10 ,
		} ,
		seasideMarket = {
			enabled = false ,
			items = {
				"灿烂的光之碎片" ,
				"10分钟加速券" ,
			} ,
			restockBufferSec = 30 ,
		} ,
	} ,
}

local Config = {}

--- 获取屏幕尺寸
function Config.displaySize()
	return STATIC.DISPLAY.WIDTH , STATIC.DISPLAY.HEIGHT
end

--- 顶部状态 HUD 静态配置
--- @return table
function Config.hudStatic()
	return STATIC.HUD
end

--- 获取热更新配置
--- @return table
function Config.hotUpdateStatic()
	return STATIC.HOT_UPDATE
end

--- 获取卡密静态配置
--- @return table
function Config.licenseStatic()
	return STATIC.LICENSE
end

--- 获取 OCR 静态配置
--- @return table
function Config.ocrStatic()
	return STATIC.OCR
end

--- 获取主循环运行时配置
--- @return table
function Config.runtimeConfig()
	return STATIC.RUNTIME
end

--- 获取用户配置默认值
--- @return table
function Config.userDefaults()
	return STATIC.USER
end

--- 获取脚本版本号（与热更 VERSION 一致）
--- @return string
function Config.version()
	return STATIC.HOT_UPDATE.VERSION
end

return Config
