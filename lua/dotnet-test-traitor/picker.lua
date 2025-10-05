local M = {}

---@param cb fun(filter: string) Callback to handle the selected filter
M.pick_filter = function(cb)
  local opts = require("dotnet-test-traitor").opts

  ---@type snacks.picker.finder.Item[]
  local picker_items = {}

  for i, filter in ipairs(opts.filters) do
    table.insert(picker_items, {
      idx = i,
      formatted = filter.name,
      text = i .. " " .. filter.name,
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
        ---@type snacks.picker.Highlight[]
        local ret = {}
        local idx = tostring(item.idx)
        ret[#ret + 1] = { idx .. ".", "SnacksPickerIdx" }
        ret[#ret + 1] = { " " }
        ret[#ret + 1] = { item.formatted, "SnacksPickerLabel" }
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
