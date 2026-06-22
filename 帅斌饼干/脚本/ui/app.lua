--[[
模块: 主界面
路径: ui.app
--]]

local Components = require("ui.components")
local Config = require("config")
local HotUpdate = require("lib.hot-update")
local License = require("lib.license")
local Ocr = require("lib.ocr")
local Runtime = require("core.runtime")
local FeatureTab = require("ui.tabs.feature-tab")
local ConfigTab = require("ui.tabs.config-tab")
local LicenseTab = require("ui.tabs.license-tab")
local Register = require("game.register")

local App = {}

function App.init()
	HotUpdate.runOnStartup()
	License.init()
	
	local ocrCfg = Config.ocrStatic()
	if not Ocr.init(ocrCfg.LICENSE , ocrCfg.REMARK) then
		print("TomatoOCR 初始化失败，OCR 功能不可用")
	end
	
	local width , height = Config.displaySize()
	local windowHandle = Components.createWindow("帅斌饼干" , width , height , true)
	LicenseTab.bindWindow(windowHandle)
	
	local tabHost = imgui.createVerticalLayout(windowHandle , - 1 , height - 138)
	local _ , featureTab , configTab , licenseTab = Components.tabbar(tabHost , { "功能" , "配置" , "卡密" })
	
	FeatureTab.build(featureTab)
	ConfigTab.build(configTab)
	LicenseTab.build(licenseTab)
	
	local shouldRun = false

	local startBtn = imgui.createButton(windowHandle , "启动脚本" , - 1 , 0)
	imgui.setOnClick(startBtn , function()
		-- 1. 授权验证
		local ok , err = License.verify()
		if not ok then
			toast(err or "请先完成授权" , 0 , 0 , 14)
			return
		end
		
		shouldRun = true
		toast("脚本已启动" , 0 , 0 , 14)
		
		setTimer(function()
			imgui.close()
		end , 0)
	end)
	
	imgui.setOnClose(windowHandle , function(handle)
		imgui.destroyWindow(handle)
	end)
	
	local result = imgui.show(true)
	if shouldRun and result == true then
		sleep(2000)
		Runtime.register = Register.all
		Runtime.run()
	end
	
	-- 检查窗口状态
	if imgui.isWindowValid(windowHandle) then
		print("窗口仍有效，正在销毁...")
		imgui.destroyWindow(windowHandle)
	end
	
	if result ~= true then
		print("imgui显示失败")
	end
	return result == true
end

return App
