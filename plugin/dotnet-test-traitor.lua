local group = vim.api.nvim_create_augroup("dotnet-test-traitor.nvim", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "cs",
  group = group,
  callback = function(event)
    vim.keymap.set("n", "<Plug>(DotnetTestTraitorRun)", function()
      local picker = require("dotnet-test-traitor.picker")

      picker.pick_filter(function(filter)
        require("dotnet-test-traitor.run")(filter)
      end)
    end, { buffer = event.buf, desc = "Run Test Category" })
  end,
})

vim.api.nvim_create_user_command("DotnetTestTraitorRun", function(opts)
  -- TODO: Support passing `is_vstest` argument
  require("dotnet-test-traitor.run")({ value = opts.args })
end, {
  nargs = 1,
})
