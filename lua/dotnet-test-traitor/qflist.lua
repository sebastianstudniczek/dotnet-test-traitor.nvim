local M = {}

---@param results dotnet-test-traitor.TestResult[]
M.set_qflist = function(results)
  local quickfix_list = {}

  for _, test in ipairs(results) do
    if test.outcome == "Failed" then
      local entry = {
        filename = test.filePath,
        lnum = test.lineNumber,
        col = 0,
        type = "E", --Error
        text = test.message .. "\n" .. test.stackTrace .. "\n" .. test.stdOut,
      }
      table.insert(quickfix_list, entry)
    end
  end

  vim.fn.setqflist({}, " ", {
    title = "dotnet-test-results",
    items = quickfix_list,
  })

  require("trouble").open({ mode = "quickfix", focus = false })
end

return M
