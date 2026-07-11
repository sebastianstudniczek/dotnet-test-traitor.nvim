---@param filter dotnet-test-traitor.TestFilter
return function(filter)
  local runner = require("dotnet-test-traitor.runner")
  local parser = require("dotnet-test-traitor.parser")
  local qflist = require("dotnet-test-traitor.qflist")

  runner.run_tests(filter, function(results_directory_path)
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

  return nil
end
