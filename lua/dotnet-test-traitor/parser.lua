local M = {}

---@param results_directory_path string Path to the directory containing .trx files
---@param cb fun(results: dotnet-test-traitor.TestSummary) Callback to handle parsed results
M.parse_test_result = function(results_directory_path, cb)
  local script_path = vim.api.nvim_get_runtime_file("scripts/test_parser.cs", true)[1]
  local command = {
    "dotnet",
    "run",
    script_path,
    "--",
    results_directory_path,
  }

  vim.notify("Executing: " .. table.concat(command, " "), "trace")

  vim.system(command, {
    text = true,
  }, function(result)
    vim.schedule(function()
      if result.code == 1 then
        vim.notify(result.stderr, vim.log.levels.ERROR)
        return
      end

      local ok, decoded = pcall(vim.json.decode, result.stdout)

      if ok and decoded then
        cb(decoded)
      else
        vim.notify("Failed to decode test parser output:\n" .. result.stdout, vim.log.levels.ERROR)
      end
    end)
  end)
end

return M
