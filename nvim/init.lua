-- Neovim configuration init.lua
-- Set leader key early
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load user configuration modules
require("user.options")
require("user.keymaps")
require("user.commands")
require("user.autocommands")

-- Setup lazy.nvim with plugins
require("lazy").setup("plugins", {
  ui = {
    -- Use a nice border for the lazy window
    border = "rounded",
  },
  change_detection = {
    -- automatically check for config file changes and reload the ui
    enabled = true,
    notify = false, -- get a notification when changes are found
  },
})