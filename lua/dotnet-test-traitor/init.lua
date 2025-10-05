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

  local group = vim.api.nvim_create_augroup("dotnet-test-traitor.nvim", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "cs",
    group = group,
    callback = function(event)
      vim.keymap.set("n", "<leader>tc", function()
        local picker = require("dotnet-test-traitor.picker")
        local runner = require("dotnet-test-traitor.runner")
        local parser = require("dotnet-test-traitor.parser")
        local qflist = require("dotnet-test-traitor.qflist")

        picker.pick_filter(function(filter)
          runner.run_tests(filter, function(results_directory_path)
            parser.parse_test_result(results_directory_path, function(summary)
              if summary.failed > 0 then
                qflist.set_qflist(summary.tests)
              else
                vim.notify(
                  string.format(
                    "Test summary: Total: %s, Failed: %s, Succeeded: %s",
                    summary.total,
                    summary.failed,
                    summary.passed
                  ),
                  vim.log.levels.INFO
                )
              end

              vim.fn.delete(results_directory_path, "rf")
            end)
          end)
        end)
      end, { buffer = event.buf, desc = "Run Test Category" })
    end,
  })
end

return M
