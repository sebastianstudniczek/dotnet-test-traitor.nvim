---@param filter dotnet-test-traitor.TestFilter
---@param result_path_file string|nil
return function(filter, result_path_file)
  local runner = require("dotnet-test-traitor.runner")
  local parser = require("dotnet-test-traitor.parser")
  local qflist = require("dotnet-test-traitor.qflist")

  local function finish(exit_code)
    if result_path_file then
      local f = io.open(result_path_file, "w")
      if f then
        f:write(tostring(exit_code))
        f:close()
      end
    end
  end

  local job_id = runner.run_tests(filter, function(results_directory_path)
    parser.parse_test_result(results_directory_path, function(summary)
      local exit_code

      if summary.failed > 0 then
        qflist.set_qflist(summary.tests)
        exit_code = 1
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
        exit_code = 0
      end

      vim.fn.delete(results_directory_path, "rf")
      finish(exit_code)
    end)
  end)

  if job_id <= 0 then
    return 1 -- failed to start job
  end
end
