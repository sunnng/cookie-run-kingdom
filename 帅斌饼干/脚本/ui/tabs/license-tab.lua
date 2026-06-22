--[[
模块: 卡密模块标签页
路径: ui.tabs.license-tab
功能: 注册码绑定/解绑、试用、充卡；标题栏显示授权状态
依赖: lib.license, ui.components, config
--]]

local License = require("lib.license")
local Components = require("ui.components")
local Config = require("config")

local LicenseTab = {}

local APP_NAME = "帅斌饼干"
local MAX_PLACARD_LEN = 48

local windowHandle = nil
local regCodeInputHandle = nil
local chargeNewInputHandle = nil
local placardText = "加载中..."

local REFRESH_DEBOUNCE_SEC = 3
local lastRefreshAt = 0

local function truncateText(text, maxLen)
	if type(text) ~= "string" or text == "" then
		return ""
	end
	if #text <= maxLen then
		return text
	end
	return string.sub(text, 1, maxLen - 3) .. "..."
end

local function formatStateText(status)
	if status.state == "registered" then
		return "已激活"
	end
	if status.state == "trial" then
		return "试用中"
	end
	return "未登录"
end

local function formatRemainingMinutes(minutes)
	if minutes == nil or minutes < 0 then
		return "剩余 --"
	end
	return string.format("剩余 %d 分钟", minutes)
end

local function buildTitleText()
	local status = License.getStatus()
	local placard = truncateText(placardText, MAX_PLACARD_LEN)
	return string.format("%s v%s | %s | %s | %s",
		APP_NAME,
		Config.version(),
		formatStateText(status),
		formatRemainingMinutes(status.remainingMinutes),
		placard)
end

local function reloadPlacard()
	local placard, err = License.getPlacard()
	placardText = placard or err or "暂无"
end

local function refreshTitle()
	if not windowHandle then
		return
	end
	Components.setWindowTitle(windowHandle, buildTitleText())
end

local function scheduleTitleRefresh()
	setTimer(function()
		refreshTitle()
		scheduleTitleRefresh()
	end, 60000)
end

--- 绑定主窗口句柄（标题栏刷新用，在 build 前调用）
--- @param handle userdata
function LicenseTab.bindWindow(handle)
	windowHandle = handle
	reloadPlacard()
	refreshTitle()
	scheduleTitleRefresh()
end

--- 构建卡密模块标签页
--- @param parent userdata
--- @return boolean ok
function LicenseTab.build(parent)
	local row = imgui.createHorticalLayout(parent, -1, 64)
	Components.textLabel(row, "注册码", 0, 0)
	regCodeInputHandle = imgui.createInputText(row, "", License.getStatus().regCode or "", 0, -1, 64)

	local btnRow = imgui.createHorticalLayout(parent, 0, 52)
	local bindBtn = imgui.createButton(btnRow, "绑定", 120, 0)
	local unbindBtn = imgui.createButton(btnRow, "解绑", 120, 0)
	local refreshBtn = imgui.createButton(btnRow, "刷新剩余", 0, 0)
	local tryBtn = imgui.createButton(btnRow, "试用登录", 0, 0)

	local function afterAuthChange()
		refreshTitle()
	end

	imgui.setOnClick(bindBtn, function()
		local code = imgui.getInputText(regCodeInputHandle)
		local ok, err = License.bind(code)
		if ok then
			afterAuthChange()
		else
			toast(err or "绑定失败", 0, 0, 14)
		end
	end)

	imgui.setOnClick(unbindBtn, function()
		local ok, err = License.unbind()
		if ok then
			imgui.setInputText(regCodeInputHandle, "")
			afterAuthChange()
		else
			toast(err or "解绑失败", 0, 0, 14)
		end
	end)

	imgui.setOnClick(refreshBtn, function()
		local now = os.time()
		if now - lastRefreshAt < REFRESH_DEBOUNCE_SEC then
			toast(string.format("请 %d 秒后再刷新", REFRESH_DEBOUNCE_SEC - (now - lastRefreshAt)), 0, 0, 14)
			return
		end
		lastRefreshAt = now

		local minutes = License.refreshRemainingMinutes()
		if minutes == -1 then
			local err = License.getStatus().message
			toast(err ~= "" and err or "刷新失败", 0, 0, 14)
		else
			toast(string.format("刷新成功，剩余 %d 分钟", minutes), 0, 0, 14)
		end
		refreshTitle()
	end)

	imgui.setOnClick(tryBtn, function()
		local code = imgui.getInputText(regCodeInputHandle)
		local ok, err = License.tryBind(code)
		if ok then
			afterAuthChange()
		else
			toast(err or "试用登录失败", 0, 0, 14)
		end
	end)

	local chargeRow = imgui.createHorticalLayout(parent, -1, 64)
	Components.textLabel(chargeRow, "新卡(充卡)", 0, 0)
	chargeNewInputHandle = imgui.createInputText(chargeRow, "", "", 0, -1, 64)

	local chargeBtn = imgui.createButton(parent, "以卡充卡", -1, 52)
	imgui.setOnClick(chargeBtn, function()
		local newCode = imgui.getInputText(chargeNewInputHandle)
		local ok, err = License.chargeCard(newCode)
		if ok then
			toast("充卡成功", 0, 0, 14)
			refreshTitle()
		else
			toast(err or "充卡失败", 0, 0, 14)
		end
	end)

	return true
end

return LicenseTab
