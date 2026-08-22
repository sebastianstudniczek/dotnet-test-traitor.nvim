local M = {}

--HACK: looks like trouble.nvim does not support pattern evaluation for quickfix list as opposed to native quickfix list
local function get_test_line(file_path, test_name)
  local method_name = test_name:match("^([%w_]+)") or test_name
  for i, line in ipairs(vim.fn.readfile(file_path)) do
    if line:find(method_name, 1, true) then
      return i
    end
  end
  return 1
end

---@param results dotnet-test-traitor.TestResult[]
M.set_qflist = function(results)
  local quickfix_list = {}
  local cwd = vim.fn.getcwd()

  for _, test in ipairs(results) do
    if test.outcome == "Failed" then
      local entry = {
        col = 0,
        type = "E", --Error
        text = test.message .. "\n" .. (test.stackTrace or "") .. "\n" .. (test.stdOut or ""),
      }

      if test.filePath and test.lineNumber and test.lineNumber > 0 then
        entry.filename = test.filePath
        entry.lnum = test.lineNumber
      else
        -- Find file if there is no stack trace
        local class_file_name = test.className:match("[^.]+$") .. ".cs"
        local matches = vim.fs.find(class_file_name, { path = cwd, upward = false, limit = 1 })

        if #matches > 0 then
          local file_name = matches[1]
          entry.filename = file_name
          entry.lnum = get_test_line(file_name, test.testName)
          -- Vim regex word boundaries: \< match word start, \> match word end
          -- entry.pattern = [[\<]] .. test.testName .. [[\>]]
        end
      end

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
