local M = {}

M.levels = {
  TRACE = 0,
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}

M.level = M.levels.DEBUG

local log_path = vim.fn.stdpath("state") .. "/dotnet-test-traitor.log"

---@param level string
---@param message string
local function log(level, message)
  local level_num = M.levels[level]
  if level_num < M.level then
    return
  end

  local time = os.date("%Y-%m-%d %H:%M:%S")
  local line = string.format("[%s] [%s] %s\n", time, level, message)

  local file = io.open(log_path, "a")
  if file then
    file:write(line)
    file:close()
  end
end

function M.trace(message, ...)
  log("TRACE", string.format(message, ...))
end
function M.debug(message, ...)
  log("DEBUG", string.format(message, ...))
end
function M.info(message, ...)
  log("INFO", string.format(message, ...))
end
function M.warn(message, ...)
  log("WARN", string.format(message, ...))
end
function M.error(message, ...)
  log("ERROR", string.format(message, ...))
end

function M.set_level(level_name)
  if M.levels[level_name] then
    M.level = M.levels[level_name]
  end
end

function M.get_path()
  return log_path
end

return M
