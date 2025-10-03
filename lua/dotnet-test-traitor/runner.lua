local M = {}

---@param filter string Test filter to apply
---@param cb fun(logFilePath: string) Callback to handle the path to the test results log file
M.run_tests = function(filter, cb)
  local logFilePath = vim.fn.tempname() .. "test_results.trx"
  local spinner = require("easy-dotnet.ui-modules.spinner").new()
  spinner:start_spinner("Running tests")

  local filterCmd = #filter > 0 and string.format("--filter '%s'", filter) or ""
  local testCommand = string.format(
    "dotnet test --nologo --no-build --no-restore %s --logger='trx;logFileName=%s'",
    filterCmd,
    logFilePath
  )

  vim.notify("Executing: " .. testCommand, vim.log.levels.INFO)

  vim.fn.jobstart(testCommand, {
    on_exit = function(_, _)
      -- Not checking exit code since it will return non-zero if any tests fail
      spinner:stop_spinner("Tests completed")
      cb(logFilePath)
    end,
  })
end

return M
