---@param filter dotnet-test-traitor.TestFilter
---@param run_sync boolean
return function(filter, run_sync)
  local runner = require("dotnet-test-traitor.runner")
  local parser = require("dotnet-test-traitor.parser")
  local qflist = require("dotnet-test-traitor.qflist")

  local job_id = runner.run_tests(filter, function(results_directory_path)
    parser.parse_test_result(results_directory_path, function(summary)
      if summary.failed > 0 then
        qflist.set_qflist(summary.tests)
      else
        vim.notify(
          string.format(
            "Test summary: Total: %s, Failed: %s, Succeeded: %s",
            summary.total,
            summary.failed,
            summary.passed
          ),
          vim.log.levels.INFO
        )
      end

      vim.fn.delete(results_directory_path, "rf")
    end)
  end)

  if job_id <= 0 then
    return 1 -- failed to start job
  end

  if run_sync then
    local exit_codes = vim.fn.jobwait({ job_id })
    return exit_codes[1]
  end

  return nil
end
