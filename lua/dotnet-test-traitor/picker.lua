local M = {}

---@param cb fun(filter: dotnet-test-traitor.TestFilter) Callback to handle the selected filter
M.pick_filter = function(cb)
  local opts = require("dotnet-test-traitor").opts

  vim.ui.select(opts.filters, {
    prompt = "Select filter:",
    format_item = function(item)
      return ("%s %s"):format(item.name, item.value)
    end,
  }, function(choice)
    cb(choice)
  end)
end

return M
