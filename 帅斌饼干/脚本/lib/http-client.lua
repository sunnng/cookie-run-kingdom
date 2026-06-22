--[[
模块: HTTP 客户端
路径: lib.http-client
功能: 封装 httpGet，统一超时与错误模型
--]]

local M = {}

local DEFAULT_TIMEOUT = 30

--- GET 请求
--- @param url string
--- @param timeoutSec number|nil
--- @return string|nil body
--- @return string|nil err
function M.get(url, timeoutSec)
    local body, statusCode = httpGet(url, timeoutSec or DEFAULT_TIMEOUT)
    if statusCode ~= 200 then
        return nil, "操作失败:通讯失败,通讯错误码:" .. tostring(statusCode)
    end
    if not body or body == "" then
        return nil, "操作失败:返回值为空"
    end
    if string.find(body, "操作失败", 1, true) then
        return nil, body
    end
    return body
end

return M
