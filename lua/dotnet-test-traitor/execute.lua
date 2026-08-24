local runner = require("dotnet-test-traitor.runner")
local parser = require("dotnet-test-traitor.parser")
local qflist = require("dotnet-test-traitor.qflist")
local async = require("dotnet-test-traitor.async")
local log = require("dotnet-test-traitor.log")

---@param filter dotnet-test-traitor.TestFilter
---@param result_path_file? string file to which write exit code
---@param args? string[] arguments passed into `dotnet test` command
return function(filter, result_path_file, args)
  ---@param exit_code integer
  ---@param results_directory_path? string
  local function finish(exit_code, results_directory_path)
    if results_directory_path then
      vim.fn.delete(results_directory_path, "rf")
    end
    if result_path_file then
      local f = io.open(result_path_file, "w")
      if f then
        f:write(tostring(exit_code))
        f:close()
      end
    end
  end

  local spinner = require("fidget.progress").handle.create({
    title = "Executing",
    lsp_client = {
      name = "dotnet-test-traitor",
    },
  })

  ---@param message string
  ---@param is_finish? boolean
  local function set_progress(message, is_finish)
    spinner.message = message
    log.info("Progress: %s", message)

    if is_finish then
      spinner:finish()
    end
  end

  async.run(function()
    local ok, err = xpcall(function()
      set_progress("running tests")
      local test_run_succeded, trx_results_directory = runner.run_tests(filter, args)

      if not test_run_succeded or trx_results_directory == nil then
        set_progress("test run failed", true)
        finish(1)
        return
      end

      set_progress("parsing test result", false)
      local parse_succeded, test_summary = parser.parse_test_result(trx_results_directory)

      if not parse_succeded or not test_summary then
        set_progress("parsing trx report(s) failed", true)
        finish(1, trx_results_directory)
        return
      end

      set_progress("trx report(s) parsed", true)

      local any_test_failed = test_summary.failed > 0
      if any_test_failed then
        qflist.set_qflist(test_summary.tests)
      else
        local msg = string.format(
          "Test summary: Total: %s, Failed: %s, Succeeded: %s",
          test_summary.total,
          test_summary.failed,
          test_summary.passed
        )
        log.info(msg)
        vim.notify(msg, vim.log.levels.INFO)
      end

      finish(any_test_failed and 1 or 0, trx_results_directory)
    end, debug.traceback)

    if not ok then
      log.error("Unhandled error in test execution:\n%s", err)
      finish(1)
    end
  end)
end
