local Color = require("lib.color")
local Ocr = require("lib.ocr")
local Logger = require("lib.logger")
local StatusHud = require("lib.status-hud")
local Touch = require("lib.touch")
local UserConfig = require("lib.user-config")

local Task = {}

--- 从字符串末尾反向提取数字（支持小数）
--- 返回: number|nil, string(name)
local function extractNumber(str)
	if not str or str == "" then
		return nil , ""
	end
	
	local len = #str
	local startPos = len + 1 -- 数字起始位置
	
	-- 从末尾逐个字符检查
	for i = len , 1 , - 1 do
		local c = str:sub(i , i)
		if c:match("[%d%.]") then
			startPos = i
		else
			break
		end
	end
	
	if startPos > len then
		return nil , str
	end
	
	local numStr = str:sub(startPos , len)
	local name = str:sub(1 , startPos - 1)
	
	-- 清理名称首尾空格
	name = name:gsub("^%s+" , ""):gsub("%s+$" , "")
	
	return tonumber(numStr) , name
end

--- 按 % 拆分并解析
local function parseRaw(text)
	if not text or text == "" then
		return {}
	end
	
	local result = {}
	
	for part in text:gmatch("([^%%]+)") do
		if part ~= "" then
			local value , name = extractNumber(part)
			if value and name ~= "" then
				result[#result + 1] = {
					name = name ,
					value = value ,
					raw = part .. "%" ,
				}
			end
		end
	end
	
	return result
end

--- 读取词条,返回符合要求的格式
local function readEffects()
	local scan = Ocr.scan({ 427 , 390 , 1162 , 760 } , 3 , "text")
	local raw = scan and scan.raw or ""
	local result = parseRaw(raw)

	-- 脆饼固定 4 条副词条；OCR 多识别时截断，不足时补空
	if #result > 4 then
		for i = #result , 5 , - 1 do
			table.remove(result , i)
		end
	end
	while #result < 4 do
		result[#result + 1] = { name = "未知" , value = 0 , raw = "" }
	end
	
	--[===[	{
	1 ==> {
	name ==> "暗黑属性伤害提升",
	raw ==> "暗黑属性伤害提升10.8%",
	value ==> 10.8,
	},
	2 ==> {
	name ==> "生命值",
	raw ==> "生命值3%",
	value ==> 3,
	},
	3 ==> {
	name ==> "生命值",
	raw ==> "生命值7.9%",
	value ==> 7.9,
	},
	4 ==> {
	name ==> "会心",
	raw ==> "会心3.7%",
	value ==> 3.7,
	},
	}]===]
	return result
end

-- ========== 总和规则检查: 同名词条数量≥count，取最高 count 条求和 ≥ minSum ==========
local function checkSums(effects , sumRules)
	if not sumRules or #sumRules == 0 then
		return false , "未配置总和规则"
	end

	for _ , r in ipairs(sumRules) do
		if r.enabled and r.name ~= "" and type(r.count) == "number" and r.count > 0 and type(r.minSum) == "number" then
			local need = math.min(4 , math.floor(r.count))
			local values = {}
			for _ , e in ipairs(effects) do
				if e.name == r.name then
					values[#values + 1] = e.value
				end
			end
			if #values >= need then
				table.sort(values , function(a , b)
					return a > b
				end)
				local sum = 0
				for i = 1 , need do
					sum = sum + values[i]
				end
				if sum >= r.minSum then
					return true , string.format("[%s]取高%d条 总和%.1f≥%.1f" , r.name , need , sum , r.minSum)
				end
			end
		end
	end

	return false , "总和规则未满足"
end

--- 按照用户选择的目标词条, 判断脆饼的词条是否满足目标词条的最小值
local function checkSlots(effects , targets)
	-- 1. 收集启用的规则
	local active = {}
	for _ , r in ipairs(targets) do
		if r.enabled and r.name ~= "" and r.name ~= nil then
			active[#active + 1] = { name = r.name , min = r.minPercent }
		end
	end
	
	if #active == 0 then
		return false , "无槽位规则"
	end
	
	-- 2. 复制实际词条，准备标记使用状态
	local pool = {}
	for i , e in ipairs(effects) do
		pool[i] = { name = e.name , value = e.value , used = false }
	end
	
	-- 3. 规则按阈值降序排序（最难满足的优先拿词条）
	table.sort(active , function(a , b)
		return a.min > b.min
	end)
	
	-- 4. 逐条匹配：每个规则在未使用的实际词条中找第一个满足的
	for _ , rule in ipairs(active) do
		local found = false
		for _ , e in ipairs(pool) do
			if not e.used and e.name == rule.name and e.value >= rule.min then
				e.used = true
				found = true
				break
			end
		end
		if not found then
			return false , string.format("缺[%s>=%s]" , rule.name , rule.min)
		end
	end
	
	return true , "毕业"
end

-- ========== 整合检查：槽位 或 总和 满足其一 ==========
local function check(effects , targets , sumRules)
	local ok1 , msg1 = checkSlots(effects , targets)
	if ok1 then
		return true , msg1
	end

	if sumRules then
		local ok2 , msg2 = checkSums(effects , sumRules)
		if ok2 then
			return true , msg2
		end
	end

	return false , msg1
end

function Task.run()
	Logger.info("[洗脆饼词条] 开始")
	
	local isConfirmResetDialog = false
	local isConfirmSameDialog = false
	
	local config = UserConfig.get("biscuit")
	local maxRolls = config.maxRolls
	local targets = config.targets
	local sumRules = config.sumRules
	local graduated = false

	StatusHud.setBiscuitReroll({ current = 0, max = maxRolls })

	local currentRolls = 0
	while currentRolls < maxRolls do
		currentRolls = currentRolls + 1
		StatusHud.setBiscuitReroll({ current = currentRolls, max = maxRolls })

		local effects = readEffects()

		local res , msg = check(effects , targets , sumRules)

		if res == true then
			graduated = true
			StatusHud.setBiscuitReroll({ current = currentRolls, max = maxRolls, extra = "已毕业" })
			Logger.info(string.format("[洗脆饼词条] %s" , msg))
			UserConfig.set("biscuit" , { enabled = false })
			break
		end
		
		Touch.tapArea({914 , 815 , 961 , 851} , 1000)
		
		-- 确认重置弹窗
		if not isConfirmResetDialog and Color.match({"1026|627|7ace0e-101010,745|629|0ca6df-101010,863|257|363d5f-101010,782|466|505050-101010,785|419|505050-101010" , 0.9}) then
			Touch.tapArea({874 , 727 , 887 , 740} , 1000)	-- 点击今日不再显示
			isConfirmResetDialog =true
			Touch.tapArea({932 , 624 , 977 , 643} , 1000)	-- 点击确认
		end
		
		-- 确认相同脆饼弹窗
		if not isConfirmSameDialog and Color.match({"1041|635|7ace0e-101010,711|632|0ca6df-101010,815|263|f70b05-101010,972|257|363d5f-101010,802|248|ffffff-101010,836|440|505050-101010" , 0.9}) then
			Touch.tapArea({876 , 725 , 885 , 739} , 1000)	-- 点击今日不再显示
			isConfirmSameDialog = true
			Touch.tapArea({942 , 626 , 971 , 641} , 1000)	-- 点击确认
		end
	end

	if not graduated and currentRolls >= maxRolls then
		StatusHud.setBiscuitReroll({ current = currentRolls, max = maxRolls, extra = "已达上限" })
	end
end

return Task
