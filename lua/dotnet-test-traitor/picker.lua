local M = {}

---@param cb fun(filter: string) Callback to handle the selected filter
M.pick_filter = function(cb)
  local opts = require("dotnet-test-traitor").opts

  ---@type snacks.picker.finder.Item[]
  local picker_items = {}

  vim.inspect(opts.filters)
  for i, filter in ipairs(opts.filters) do
    table.insert(picker_items, {
      idx = i,
      text = filter.name,
      value = filter.value,
    })
  end

  local padding = 15

  require("snacks").picker.pick(
    ---@type snacks.picker.Config
    {
      source = "Test filters",
      items = picker_items,
      format = function(item, _)
        local ret = {}
        ret[#ret + 1] = { item.text, "SnacksPickerLabel" }
        ret[#ret + 1] = { string.rep(" ", padding - #item.text), virtual = true }
        ret[#ret + 1] = { item.value, "SnacksPickerComment" }
        return ret
      end,
      confirm = function(picker, item)
        picker:close()
        cb(item.value)
      end,
      layout = {
        preview = false,
        layout = {
          width = 0.4,
          min_width = 80,
          height = 0.2,
          min_height = 10,
        },
      },
    }
  )
end

return M
