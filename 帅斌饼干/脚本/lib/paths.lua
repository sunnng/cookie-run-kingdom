--[[
模块: 路径工具
路径: lib.paths
功能: 工作目录与数据文件路径
依赖: getWorkPath, fileExist, mkdir
--]]

local M = {}

--- 获取数据目录路径
--- @return string path
function M.getDataDir()
    return getWorkPath() .. "/data"
end

--- 获取卡密会话文件路径
--- @return string path
function M.getLicensePath()
    return M.getDataDir() .. "/license.json"
end

--- 获取运行日志路径
--- @return string path
function M.getLogPath()
	return M.getDataDir() .. "/run.log"
end

--- 获取 store 文件路径
--- @return string path
function M.getStorePath()
	return M.getDataDir() .. "/store.json"
end

--- 确保数据目录存在
--- @return boolean ok
function M.ensureDataDir()
    local dir = M.getDataDir()
    if fileExist(dir) then
        return true
    end
    return mkdir(dir) == true
end

return M
