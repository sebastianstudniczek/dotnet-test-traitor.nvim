local M = {}

---@param results_directory_path string Path to the directory containing .trx files
---@param cb fun(results: dotnet-test-traitor.TestSummary) Callback to handle parsed results
M.parse_test_result = function(results_directory_path, cb)
  local script_path = vim.api.nvim_get_runtime_file("scripts/test_parser.cs", true)[1]
  local command = string.format("dotnet run %s %s", script_path, results_directory_path)
  local spinner = require("fidget.progress").handle.create({
    title = "Parsing test results",
    message = "parsing",
    lsp_client = {
      name = "dotnet-test-traitor",
    },
  })

  vim.notify("Executing: " .. command, "trace")

  local stderr = {}
  local stdout = {}
  vim.fn.jobstart(command, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stderr = function(_, data)
      stderr = data
    end,
    on_stdout = function(_, data)
      stdout = data
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        spinner.message = "failed with exit code " .. code
        spinner:finish()
        vim.notify(table.concat(stderr, "\n"), vim.log.levels.ERROR)
        return
      end

      local ok, decoded = pcall(vim.fn.json_decode, stdout)
      if ok and decoded then
        spinner.message = "parsed successfully"
        cb(decoded)
      else
        spinner.message = "failed to decode json"
      end
      spinner:finish()
    end,
  })
end

return M
