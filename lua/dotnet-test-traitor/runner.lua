local M = {}

local async = require("dotnet-test-traitor.async")
local log = require("dotnet-test-traitor.log")

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

---@param filter dotnet-test-traitor.TestFilter
---@param args string[]|nil
---@return string[] cmd, string trx_results_directory
local function prepare_test_cmd(filter, args)
  local results_directory = vim.loop.os_tmpdir() .. "/nvim/dotnet-test-traitor/tests_results_" .. os.time()
  vim.fn.mkdir(results_directory, "p")

  local test_command = {
    "dotnet",
    "test",
    -- "/clp:ErrorsOnly",
  }

  vim.list_extend(test_command, get_filter_args(filter))

  if filter.is_vstest then
    vim.list_extend(test_command, { "--logger", "trx" })
  else
    table.insert(test_command, "--report-trx")
  end

  vim.list_extend(test_command, { "--results-directory", results_directory })
  vim.list_extend(test_command, args or {})

  return test_command, results_directory
end

---@param filter dotnet-test-traitor.TestFilter Test filter to apply
---@param args? string[] Additional arguments passed into `dotnet test` command
---@return boolean success, string? trx_results_directory
M.run_tests = function(filter, args)
  local test_command, trx_resulsts_directory = prepare_test_cmd(filter, args)
  log.debug("Executing: %s", vim.inspect(test_command))

  local test_result = async.system(test_command, { text = true })
  log.debug("[test run stdout]:\n%s", test_result.stdout or "")
  log.debug("[test run stderr]:\n%s", test_result.stderr or "")

  if test_result.code == 1 then
    local output = test_result.stdout .. "\n" .. test_result.stderr
    local lines = vim.split(output, "\n", { plain = true })

    vim.fn.setqflist({}, " ", {
      title = "dotnet build",
      lines = lines,
      efm = table.concat({
        "%f(%l\\,%c): %trror %m",
        "%f(%l): %trror %m",
        "%-G%.%#", -- ignore-other lines
      }, ","),
    })

    require("trouble").open({ mode = "quickfix", focus = false })
    return false, nil
  end

  -- 2 - at least one test failed
  local success = test_result.code == 2 or test_result.code == 0
  if not success then
    log.error("Test execution failed: %s%s", test_result.stdout, test_result.stderr)
  end

  return success, trx_resulsts_directory
end

return M
