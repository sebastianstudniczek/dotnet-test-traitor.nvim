local M = {}

---@param xml_path string Path to the .trx file
---@param cb fun(results: dotnet-test-traitor.TestCaseResult[]) Callback to handle parsed results
M.parse_test_result = function(xml_path, cb)
  local script_path = vim.api.nvim_get_runtime_file("scripts/test_parser.fsx", true)[1]
  local command = string.format("dotnet fsi %s %s", script_path, xml_path)
  local spinner = require("easy-dotnet.ui-modules.spinner").new()
  spinner:start_spinner("Parsing test results")

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
        spinner:stop_spinner("Parsing tests failed with exit code " .. code, vim.log.levels.ERROR)
        vim.notify(table.concat(stderr, "\n"), vim.log.levels.ERROR)
        return
      end

      local ok, decoded = pcall(vim.fn.json_decode, stdout)
      if ok and decoded then
        spinner:stop_spinner("Test results parsed successfully")
        cb(decoded)
      else
        spinner:stop_spinner("Failed to decode json ", vim.log.levels.ERROR)
      end
    end,
  })
end

return M
