local M = {}

---@param cmd string[]
---@param opts? vim.SystemOpts
---@return vim.SystemCompleted
M.system = function(cmd, opts)
  local co, is_main = coroutine.running()
  assert(co and not is_main, "async function must be run within a coroutine")

  vim.system(cmd, opts, function(result)
    vim.schedule(function()
      local ok, err = coroutine.resume(co, result)

      if not ok then
        vim.notify(debug.traceback(co, err), vim.log.levels.ERROR)
      end
    end)
  end)

  return coroutine.yield()
end

---@param fn fun()
M.run = function(fn)
  local co = coroutine.create(fn)

  local ok, err = coroutine.resume(co)
  if not ok then
    vim.notify(debug.traceback(co, err), vim.log.levels.ERROR)
  end
end

return M
