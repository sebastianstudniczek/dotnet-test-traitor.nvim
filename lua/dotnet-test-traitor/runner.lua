local M = {}

---@param filter dotnet-test-traitor.TestFilter
local function get_filter_cmd(filter)
  if #filter.value == 0 then
    return ""
  end

  if filter.is_vstest then
    return string.format("--filter '%s'", filter.value)
  else
    return string.format("--treenode-filter '%s'", filter.value)
  end
end

---@param filter dotnet-test-traitor.TestFilter Test filter to apply
---@param cb fun(runner_exit_code: number, logFilePath: string) Callback to handle the path to the test results log file
---@return number jobId
M.run_tests = function(filter, cb)
  local results_directory = vim.loop.os_tmpdir() .. "/nvim/dotnet-test-traitor/tests_results_" .. os.time()
  vim.fn.mkdir(results_directory, "p")
  local spinner = require("fidget.progress").handle.create({
    title = "Running tests",
    message = "running",
    lsp_client = {
      name = "dotnet-test-traitor",
    },
  })

  local filter_cmd = get_filter_cmd(filter)
  local logger_cmd = filter.is_vstest and "--logger 'trx'" or "--report-trx --ignore-exit-code 8"
  local testCommand =
    string.format("dotnet test %s %s --results-directory '%s'", filter_cmd, logger_cmd, results_directory)

  vim.notify("Executing: " .. testCommand, vim.log.levels.TRACE)

  local output = {}

  ---@type vim.fn.jobstart.Opts
  local job_opts = {
    on_stdout = function(_, data)
      vim.list_extend(output, data)
    end,
    on_stderr = function(_, data)
      vim.list_extend(output, data)
    end,
    on_exit = function(_, exit_code)
      -- if there are different error codes then `1` works as an aggregated result
      if exit_code == 1 then
        spinner.message = "failed"
        spinner:finish()
        vim.notify(table.concat(output, "\n"), "error")
        cb(exit_code, results_directory)
        return
      end
      spinner.message = "completed"
      spinner:finish()
      cb(exit_code, results_directory)
    end,
    stderr_buffered = true,
    stdout_buffered = true,
  }

  return vim.fn.jobstart(testCommand, job_opts)
end

return M
