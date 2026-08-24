local plugin_dir = vim.fn.getcwd()
vim.opt.rtp:prepend(plugin_dir)

local packpath = vim.fn.stdpath("data") .. "/site/pack/test/start"
local trouble_dir = packpath .. "/trouble.nvim"
local fidget_dir = packpath .. "/fidget.nvim"

local function clone_if_needed(url, dir)
  if not vim.uv.fs_stat(dir) then
    vim.fn.system({ "git", "clone", "--depth", "1", url, dir })
  end
  vim.opt.rtp:prepend(dir)
end

clone_if_needed("https://github.com/folke/trouble.nvim.git", trouble_dir)
clone_if_needed("https://github.com/j-hui/fidget.nvim.git", fidget_dir)
