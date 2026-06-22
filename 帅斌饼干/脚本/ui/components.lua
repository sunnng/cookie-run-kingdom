--[[
模块: UI 组件
路径: ui.components
功能: 可复用 imgui 控件封装
依赖: imgui, config
--]]

local Components = {}
local AppConfig = require("config")

local SCREEN_WIDTH , SCREEN_HEIGHT = AppConfig.displaySize()

--- 创建居中 imgui 主窗口
--- @param title string 窗口标题
--- @param width number 宽度
--- @param height number 高度
--- @param showclose boolean|nil 是否显示关闭按钮
--- @return userdata windowHandle
function Components.createWindow(title , width , height , showclose)
	if imgui.isSupport() == false then
		print("当前环境不支持IMGUI")
		exitScript()
	end
	
	assert(type(width) == "number" and width > 0 , "width must be a positive number")
	assert(type(height) == "number" and height > 0 , "height must be a positive number")
	local x = math.max(0 , (SCREEN_WIDTH - width) / 2)
	local y = math.max(0 , (SCREEN_HEIGHT - height) / 2)
	local windowHandle = imgui.createWindow(title , x , y , width , height , showclose)
	
	imgui.setWidgetStyle(windowHandle , ImGuiStyleVar.WindowPadding , 12.0 , 12.0)
	-- 设置滚动条圆角
	imgui.setWidgetStyle(windowHandle , ImGuiStyleVar.ScrollbarRounding , 0.0)
	imgui.setWindowFlags(windowHandle ,
	WindowFlags.NoResize
	| WindowFlags.NoMove
	| WindowFlags.NoScrollbar
	| WindowFlags.NoScrollWithMouse
	| WindowFlags.NoSavedSettings)
	imgui.setColorTheme(0)

	return windowHandle
end

--- 创建透明背景的文字标签（按钮实现，仅展示文本）
--- @param parent userdata 父容器句柄
--- @param text string 标签文本
--- @param width number|nil 宽度，默认 0（自动）
--- @param height number|nil 高度，默认 0（自动）
--- @return userdata labelHandle
function Components.textLabel(parent , text , width , height)
	local labelHandle = imgui.createButton(parent , text , width or 0 , height or 0)
	imgui.setWidgetColor(labelHandle , ImGuiColor.Button , 0x00000000)
	imgui.setWidgetColor(labelHandle , ImGuiColor.ButtonHovered , 0x00000000)
	imgui.setWidgetColor(labelHandle , ImGuiColor.ButtonActive , 0x00000000)
	return labelHandle
end

--- 创建标签栏并批量添加标签页
--- @param parent userdata 父窗口句柄
--- @param titles string[] 标签页标题列表
--- @param barTitle string|nil 标签栏标识，默认 "tab"
--- @return userdata tabbarHandle
--- @return userdata ... tabs
function Components.tabbar(parent , titles , barTitle)
	local tabbarHandle = imgui.createTabBar(parent , barTitle or "tab")
	imgui.setWidgetStyle(tabbarHandle , ImGuiStyleVar.TabRounding , 0)
	
	local tabHandles = {}
	for i , title in ipairs(titles) do
		tabHandles[i] = imgui.addTabBarItem(tabbarHandle , title)
	end
	
	return tabbarHandle , table.unpack(tabHandles)
end

--- 更新窗口标题栏文本
--- @param windowHandle userdata
--- @param title string
function Components.setWindowTitle(windowHandle , title)
	imgui.setWidgetText(windowHandle , title)
end

--- 更新 textLabel 等控件文本
--- @param widgetHandle userdata
--- @param text string
function Components.setText(widgetHandle , text)
	imgui.setWidgetText(widgetHandle , text)
end

--- 创建「左侧标签 + 右侧输入框」行
--- @param parent userdata
--- @param label string
--- @param value string|number
--- @param inputWidth number|nil 输入框宽度，默认 -1（自适应）
--- @param rowHeight number|nil 行高，默认 72
--- @return userdata inputHandle
function Components.labeledInput(parent , label , value , inputWidth , rowHeight , isBorder)
	local height = rowHeight or 80
	local row = imgui.createHorticalLayout(parent , - 1 , height)
	imgui.setLayoutBorderVisible(row , isBorder or false)
	imgui.setWidgetStyle(row , ImGuiStyleVar.ItemSpacing , 8 , 0)
	Components.textLabel(row , label , 0 , 0)
	local inputHandle = imgui.createInputText(row , "" , tostring(value) , 0 , inputWidth or - 1 , height)
	return inputHandle
end

return Components
