local M = {}

local async = require("dotnet-test-traitor.async")

---@param results_directory_path string Path to the directory containing .trx files
---@return boolean success, dotnet-test-traitor.TestSummary? test_summary
M.parse_test_result = function(results_directory_path)
  local script_path = vim.api.nvim_get_runtime_file("scripts/trx_reports_parser.cs", true)[1]
  local command = {
    "dotnet",
    "run",
    script_path,
    "--",
    results_directory_path,
  }

  vim.notify("Executing: " .. table.concat(command, " "), vim.log.levels.TRACE)

  local result = async.system(command, {
    text = true,
  })

  if result.code == 1 then
    vim.notify(result.stderr, vim.log.levels.ERROR)
    return false
  end

  local ok, decoded = pcall(vim.json.decode, result.stdout)

  if ok and decoded then
    return true, decoded
  else
    vim.notify("Failed to decode test parser output:\n" .. result.stdout, vim.log.levels.ERROR)
    return false
  end
end

return M
