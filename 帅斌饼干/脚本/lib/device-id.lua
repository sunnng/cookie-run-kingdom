--[[
模块: 设备码
路径: lib.device-id
功能: 百宝云机器码
--]]

local M = {}

function M.getDeviceCode()
    local hash = MD5(getDeviceId())
    local digits = string.gsub(hash, "%D", "")
    return string.sub(digits, 3, 3)
        .. string.sub(digits, 10, 10)
        .. string.sub(digits, -1, -1)
        .. string.sub(digits, -5, -5)
        .. string.sub(digits, -9, -9)
        .. string.sub(digits, -14, -14)
end

return M
