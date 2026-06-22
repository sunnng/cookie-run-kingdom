--[[
模块: 字符串工具
路径: lib.string-util
--]]

local M = {}

function M.split(str, delim)
    if type(str) ~= "string" or type(delim) ~= "string" or #delim == 0 then
        return nil
    end
    local parts = {}
    local start = 1
    while true do
        local pos = string.find(str, delim, start, true)
        if not pos then
            break
        end
        parts[#parts + 1] = string.sub(str, start, pos - 1)
        start = pos + #delim
    end
    parts[#parts + 1] = string.sub(str, start)
    return parts
end

function M.trim(str)
    if type(str) ~= "string" then
        return ""
    end
    return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

return M
