local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Vim options from vimrc
vim.opt.number = true
vim.opt.showcmd = true
vim.opt.autoindent = true
vim.opt.expandtab = true
vim.opt.smarttab = true
vim.opt.shiftwidth = 3
vim.opt.softtabstop = 3
vim.opt.wildmenu = true
vim.opt.wildmode = "list:longest,full"
vim.opt.mouse = "a"
vim.opt.backspace = "2"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.hlsearch = true
vim.opt.hidden = false
vim.opt.laststatus = 2
vim.opt.foldmethod = "marker"

-- require('user.options') -- Load custom options
-- require('user.keymaps') -- Load custom keymaps
-- require('user.autocommands') -- Load custom autocommands
-- require('user.commands') -- Load custom commands

require("lazy").setup({
  spec = {
    {
      "yetone/avante.nvim",
      event = "VeryLazy",
      lazy = false,
      version = false,
      opts = {
        provider = "copilot",
        auto_suggestions = true,
        copilot = {
          endpoint = "https://api.githubcopilot.com",
          model = "gpt-4o-2024-05-13",
          proxy = nil,
          allow_insecure = false,
          timeout = 30000,
        },
        behaviour = {
          auto_suggestions = true,
          auto_set_highlight_group = true,
          auto_set_keymaps = true,
          auto_apply_diff_after_generation = false,
          support_paste_from_clipboard = false,
        },
        mappings = {
          ask = "<leader>aa",
          edit = "<leader>ae",
          refresh = "<leader>ar",
          diff = {
            ours = "co",
            theirs = "ct",
            all_theirs = "ca",
            both = "cb",
            cursor = "cc",
            next = "]x",
            prev = "[x",
          },
          suggestion = {
            accept = "<M-l>",
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<C-]>",
          },
        },
      },
      build = "make",
      dependencies = {
        "stevearc/dressing.nvim",
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
        "hrsh7th/nvim-cmp",
        "github/copilot.vim",
        {
          "HakonHarnes/img-clip.nvim",
          event = "VeryLazy",
          opts = {
            default = {
              embed_image_as_base64 = false,
              prompt_for_file_name = false,
              drag_and_drop = {
                insert_mode = true,
              },
              use_absolute_path = true,
            },
          },
        },
        {
          'MeanderingProgrammer/render-markdown.nvim',
          opts = {
            file_types = { "markdown", "Avante" },
          },
          ft = { "markdown", "Avante" },
        },
      },
    },
    {
      "nvim-lualine/lualine.nvim",
      config = function()
        require("lualine").setup({
          options = {
            theme = "auto",
            component_separators = { left = "", right = "" },
            section_separators = { left = "", right = "" },
          },
        })
      end
    },
    {
      "nvim-tree/nvim-tree.lua",
      config = function()
        require("nvim-tree").setup({
          sort_by = "case_sensitive",
          view = { width = 30 },
          renderer = { group_empty = true },
          filters = { dotfiles = true },
        })
        vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true })
      end
    },
    {
      "folke/tokyonight.nvim",
      lazy = false,
      priority = 1000,
      config = function()
        vim.cmd([[colorscheme tokyonight]])
      end
    },
    {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      config = function()
        require("nvim-treesitter.configs").setup({
          ensure_installed = { "lua", "vim", "javascript", "python" },
          highlight = { enable = true },
        })
      end
    },
    {
      "nvim-telescope/telescope.nvim",
      dependencies = { "nvim-lua/plenary.nvim" },
      config = function()
        local builtin = require("telescope.builtin")
        vim.keymap.set("n", "<leader>ff", builtin.find_files)
        vim.keymap.set("n", "<leader>fg", builtin.live_grep)
      end
    },
    {
      "3rd/image.nvim",
      config = function()
        require("image").setup()
      end
    },
    {
      "lewis6991/gitsigns.nvim",
      config = function()
        require("gitsigns").setup()
      end
    },
    {
      "mfussenegger/nvim-dap",
      dependencies = {
        "rcarriga/nvim-dap-ui",
        "theHamsta/nvim-dap-virtual-text",
      },
      config = function()
        local dap, dapui = require("dap"), require("dapui")
        dapui.setup()
        require("nvim-dap-virtual-text").setup()
        
        vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint)
        vim.keymap.set("n", "<leader>dc", dap.continue)
        
        dap.listeners.after.event_initialized["dapui_config"] = function()
          dapui.open()
        end
        dap.listeners.before.event_terminated["dapui_config"] = function()
          dapui.close()
        end
      end
    },
    {
      "folke/which-key.nvim",
      event = "VeryLazy",
      config = function()
        require("which-key").setup()
      end
    },
    {
      "akinsho/toggleterm.nvim",
      version = "*",
      config = function()
        require("toggleterm").setup({
          open_mapping = [[<c-\>]],
          direction = "float",
        })
      end
    },
    {
      "windwp/nvim-autopairs",
      event = "InsertEnter",
      config = function()
        require("nvim-autopairs").setup()
      end
    },
    {
      "ggandor/leap.nvim",
      dependencies = { "tpope/vim-repeat" },
      config = function()
        require("leap").add_default_mappings()
      end
    },
    {
      "nacro90/numb.nvim",
      config = function()
        require("numb").setup()
      end
    },
    {
      "github/copilot.vim",
      event = "InsertEnter",
      config = function()
        -- Disable default tab mapping
        vim.g.copilot_no_tab_map = true
        vim.g.copilot_assume_mapped = true
        
        -- Simple reliable mappings
        vim.api.nvim_create_autocmd("VimEnter", {
          callback = function()
            vim.keymap.set("i", "<Tab>", 'copilot#Accept("\\<CR>")', {
              expr = true,
              replace_keycodes = false,
              silent = true
            })
            vim.keymap.set("i", "<C-J>", 'copilot#Accept("\\<CR>")', {
              expr = true,
              replace_keycodes = false,
              silent = true
            })
          end,
        })
      end,
    },
    {
      "hrsh7th/nvim-cmp",
      event = "InsertEnter",
      dependencies = {
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-nvim-lsp",
      },
      config = function()
        local cmp = require("cmp")
        cmp.setup({
          mapping = cmp.mapping.preset.insert({
            ["<Tab>"] = cmp.mapping.select_next_item(),
            ["<S-Tab>"] = cmp.mapping.select_prev_item(),
            ["<CR>"] = cmp.mapping.confirm({ select = true }),
            ["<C-Space>"] = cmp.mapping.complete(),
          }),
          sources = cmp.config.sources({
            { name = "nvim_lsp" },
            { name = "buffer" },
            { name = "path" },
          }),
        })
      end,
    },
  },
  install = { colorscheme = { "tokyonight" } },
  checker = { enabled = false },
  change_detection = { enabled = false },
})

-- Key mappings from vimrc (set after plugins to avoid conflicts)
vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode with jj" })
vim.keymap.set("n", ";", ":", { desc = "Use semicolon for command mode" })
vim.keymap.set("n", ":", ";", { desc = "Use colon for repeat find" })

-- Use a different key for fold toggle since space is leader
vim.keymap.set("n", "za", "za", { desc = "Toggle fold" })

vim.keymap.set("n", "k", "gk", { desc = "Move up by display line" })
vim.keymap.set("n", "j", "gj", { desc = "Move down by display line" })
vim.keymap.set("n", "n", "nzz", { desc = "Next search result centered" })
vim.keymap.set("n", "N", "Nzz", { desc = "Previous search result centered" })

-- Tab navigation
vim.keymap.set("n", "<C-Right>", ":tabnext<CR>", { desc = "Next tab" })
vim.keymap.set("n", "<C-Left>", ":tabprevious<CR>", { desc = "Previous tab" })
vim.keymap.set("n", "<C-t>", ":tabnew<CR>", { desc = "New tab" })

-- Create blank lines
vim.keymap.set("n", "zj", "o<Esc>", { desc = "Create blank line below" })
vim.keymap.set("n", "zk", "O<Esc>", { desc = "Create blank line above" })
