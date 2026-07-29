local M = {}

---@param filter dotnet-test-traitor.TestFilter
---@return string[]
local function get_filter_args(filter)
  if #filter.value == 0 then
    return {}
  end

  if filter.is_vstest then
    return { "--filter", filter.value }
  else
    return { "--treenode-filter", filter.value }
  end
end

---@param cb fun(result: vim.SystemCompleted)
local function build(cb)
  vim.system({ "dotnet", "build", "/clp:ErrorsOnly" }, {
    text = true,
  }, function(result)
    local output = result.stdout .. "\n" .. result.stderr
    local lines = vim.split(output, "\n", { plain = true })

    vim.schedule(function()
      vim.fn.setqflist({}, " ", {
        title = "dotnet build",
        lines = lines,
        efm = table.concat({
          "%f(%l\\,%c): %trror %m",
          "%f(%l): %trror %m",
          "%-G%.%#", -- ignore-other lines
        }, ","),
      })

      if result.code ~= 0 then
        vim.cmd("copen")
      end

      cb(result)
    end)
  end)
end

---@param filter dotnet-test-traitor.TestFilter Test filter to apply
---@param args string[]|nil Additional arguments passed into `dotnet test` command
---@param cb fun(runner_exit_code: number, logFilePath: string, progress) Callback to handle the path to the test results log file
M.run_tests = function(filter, args, cb)
  local spinner = require("fidget.progress").handle.create({
    title = "Running tests",
    message = "building project",
    lsp_client = {
      name = "dotnet-test-traitor",
    },
  })

  build(function(build_result)
    if build_result.code ~= 0 then
      spinner.message = "build failed"
      spinner:finish()

      cb(build_result.code, "", spinner)
      return
    end

    spinner.message = "running tests"

    local results_directory = vim.loop.os_tmpdir() .. "/nvim/dotnet-test-traitor/tests_results_" .. os.time()
    vim.fn.mkdir(results_directory, "p")

    local test_command = {
      "dotnet",
      "test",
      "--no-build",
    }

    vim.list_extend(test_command, get_filter_args(filter))

    if filter.is_vstest then
      vim.list_extend(test_command, { "--logger", "trx" })
    else
      table.insert(test_command, "--report-trx")
    end

    vim.list_extend(test_command, { "--results-directory", results_directory })
    vim.list_extend(test_command, args or {})

    vim.notify("Executing: " .. vim.inspect(test_command), vim.log.levels.TRACE)

    vim.system(test_command, { text = true }, function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          spinner.message = "test run failed"
          spinner:finish()

          vim.notify(result.stdout .. result.stderr, vim.log.levels.ERROR)
        else
          spinner.message = "test run completed"
        end

        cb(result.code, results_directory, spinner)
      end)
    end)
  end)
end

return M
