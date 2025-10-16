local M = {}

---@param filter string Test filter to apply
---@param cb fun(logFilePath: string) Callback to handle the path to the test results log file
M.run_tests = function(filter, cb)
  local results_directory = vim.loop.os_tmpdir() .. "/nvim/dotnet-test-traitor/tests_results_" .. os.time()
  vim.fn.mkdir(results_directory, "p")
  local spinner = require("dotnet-test-traitor.spinner").new()
  spinner:start_spinner("Running tests")

  local filterCmd = #filter > 0 and string.format("--filter '%s'", filter) or ""
  local testCommand = string.format(
    "dotnet test %s --nologo %s --logger='trx' --results-directory '%s'",
    vim.g.roslyn_nvim_selected_solution or "",
    filterCmd,
    results_directory
  )

  vim.notify("Executing: " .. testCommand, vim.log.levels.INFO)

  vim.fn.jobstart(testCommand, {
    on_exit = function(_, _)
      -- Not checking exit code since it will return non-zero if any tests fail
      spinner:stop_spinner("Tests completed")
      cb(results_directory)
    end,
  })
end

return M
