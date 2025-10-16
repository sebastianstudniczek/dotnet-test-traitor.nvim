local M = {}

---@type dotnet-test-traitor.Configuration
M.defaults = {
  filters = {
    { name = "None", value = "" },
  },
}

M.opts = vim.deepcopy(M.defaults)

function M.setup(user_opts)
  M.opts.filters = vim.list_extend(vim.deepcopy(M.defaults.filters), user_opts.filters or {})
end

return M
