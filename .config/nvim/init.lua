-- Cross-platform detection
local is_windows = vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1
local is_wsl = vim.fn.has('wsl') == 1
local is_linux = vim.fn.has('unix') == 1 and not is_wsl

-- Ensure data directory exists and is writable
local data_dir = vim.fn.stdpath("data")
if vim.fn.isdirectory(data_dir) == 0 then
  vim.fn.mkdir(data_dir, "p")
end

local lazypath = data_dir .. "/lazy/lazy.nvim"
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

-- Suppress specific error messages globally
local orig_vim_schedule = vim.schedule
vim.schedule = function(fn)
  return orig_vim_schedule(function()
    local ok, err = pcall(fn)
    if not ok and type(err) == "string" then
      -- Suppress treesitter and swap file errors
      if err:match("Invalid 'end_row'") or 
         err:match("Invalid 'end_col'") or
         err:match("out of range") or
         err:match("treesitter/highlighter") or
         err:match(".swp") then
        return
      end
      -- Re-throw other errors
      error(err)
    end
  end)
end

-- Basic vim settings for cross-platform compatibility
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.swapfile = false
vim.opt.directory = vim.fn.stdpath("data") .. "/swap//"
vim.opt.undodir = vim.fn.stdpath("data") .. "/undo//"
vim.opt.backupdir = vim.fn.stdpath("data") .. "/backup//"
vim.opt.backup = false
vim.opt.undofile = true
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")
vim.opt.updatetime = 50
vim.opt.colorcolumn = "80"
vim.opt.mouse = "a"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hidden = false
vim.opt.laststatus = 2

-- Auto-reload settings for external file changes
vim.opt.autoread = true  -- Automatically read file when changed outside of vim

-- Cross-platform clipboard setup
if is_wsl then
  vim.g.clipboard = {
    name = 'WslClipboard',
    copy = {
      ['+'] = 'clip.exe',
      ['*'] = 'clip.exe',
    },
    paste = {
      ['+'] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
      ['*'] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
    },
    cache_enabled = 0,
  }
elseif is_windows then
  vim.opt.clipboard = "unnamedplus"
else
  vim.opt.clipboard = "unnamedplus"
end

require("lazy").setup({
  spec = {
    -- Core plugins by priority
    {
      "tpope/vim-sleuth", -- Auto-detect indentation
      lazy = false,
    },
    {
      "nvim-tree/nvim-web-devicons", -- File icons
      config = function()
        require("nvim-web-devicons").setup({
          override = {},
          default = true,
          strict = true,
          override_by_filename = {
            [".gitignore"] = {
              icon = "",
              color = "#f1502f",
              name = "Gitignore"
            }
          },
          override_by_extension = {
            ["log"] = {
              icon = "",
              color = "#81e043",
              name = "Log"
            }
          },
        })
      end
    },
    {
      "ibhagwan/fzf-lua", -- Fuzzy finding - excellent telescope replacement
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        local fzf = require("fzf-lua")
        
        -- Setup fzf-lua with good defaults
        fzf.setup({
          "telescope", -- Use telescope-like profile for familiar behavior
          winopts = {
            height = 0.85,
            width = 0.80,
            preview = {
              default = "bat",
              border = "border",
              wrap = "nowrap",
              hidden = "nohidden",
              vertical = "down:45%",
              horizontal = "right:60%",
              layout = "flex",
              flip_columns = 120,
            },
          },
          files = {
            prompt = "Files❯ ",
            multiprocess = true,
            git_icons = true,
            file_icons = true,
            color_icons = true,
          },
          grep = {
            prompt = "Rg❯ ",
            input_prompt = "Grep For❯ ",
            multiprocess = true,
            git_icons = true,
            file_icons = true,
            color_icons = true,
          },
        })
        
        -- File search keymaps
        vim.keymap.set("n", "<leader>ff", fzf.files, { desc = "Find files" })
        vim.keymap.set("n", "<leader>fa", function() fzf.files({ cwd = vim.fn.expand("%:p:h") }) end, { desc = "Find files in current dir" })
        vim.keymap.set("n", "<leader>fh", fzf.oldfiles, { desc = "Find recent files" })
        vim.keymap.set("n", "<C-p>", fzf.files, { desc = "Find files (Ctrl+P)" })
        
        -- Text search keymaps
        vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "Live grep" })
        vim.keymap.set("n", "<leader>fw", fzf.grep_cword, { desc = "Grep word under cursor" })
        vim.keymap.set("n", "<leader>fW", fzf.grep_cWORD, { desc = "Grep WORD under cursor" })
        vim.keymap.set("n", "<leader>fr", fzf.live_grep_resume, { desc = "Resume last grep" })
        vim.keymap.set("n", "<C-f>", fzf.live_grep, { desc = "Live grep (Ctrl+F)" })
        
        -- Buffer and navigation
        vim.keymap.set("n", "<leader>fb", fzf.buffers, { desc = "Find buffers" })
        vim.keymap.set("n", "<leader>fj", fzf.jumps, { desc = "Find jumps" })
        vim.keymap.set("n", "<leader>fm", fzf.marks, { desc = "Find marks" })
        vim.keymap.set("n", "<leader>fq", fzf.quickfix, { desc = "Find quickfix" })
        vim.keymap.set("n", "<leader>fl", fzf.loclist, { desc = "Find location list" })
        
        -- Git integration
        vim.keymap.set("n", "<leader>gc", fzf.git_commits, { desc = "Git commits" })
        vim.keymap.set("n", "<leader>gb", fzf.git_branches, { desc = "Git branches" })
        vim.keymap.set("n", "<leader>gf", fzf.git_files, { desc = "Git files" })
        vim.keymap.set("n", "<leader>gs", fzf.git_status, { desc = "Git status" })
        
        -- Help and commands
        vim.keymap.set("n", "<leader>fh", fzf.help_tags, { desc = "Find help" })
        vim.keymap.set("n", "<leader>fc", fzf.commands, { desc = "Find commands" })
        vim.keymap.set("n", "<leader>fk", fzf.keymaps, { desc = "Find keymaps" })
        
        -- LSP integration
        vim.keymap.set("n", "<leader>fs", fzf.lsp_document_symbols, { desc = "Document symbols" })
        vim.keymap.set("n", "<leader>fS", fzf.lsp_workspace_symbols, { desc = "Workspace symbols" })
        vim.keymap.set("n", "<leader>fd", fzf.lsp_definitions, { desc = "LSP definitions" })
        vim.keymap.set("n", "<leader>fD", fzf.lsp_declarations, { desc = "LSP declarations" })
        vim.keymap.set("n", "<leader>fi", fzf.lsp_implementations, { desc = "LSP implementations" })
        vim.keymap.set("n", "<leader>ft", fzf.lsp_typedefs, { desc = "LSP type definitions" })
        vim.keymap.set("n", "<leader>fR", fzf.lsp_references, { desc = "LSP references" })
      end
    },
    {
      "kylechui/nvim-surround", -- Surround text objects
      event = "VeryLazy",
      config = function()
        require("nvim-surround").setup()
      end
    },
    {
      "numToStr/Comment.nvim", -- Easy commenting
      config = function()
        require("Comment").setup()
        -- Additional keymaps for Windows Git Bash compatibility
        vim.keymap.set("n", "<leader>/", function() require("Comment.api").toggle.linewise.current() end)
        vim.keymap.set("v", "<leader>/", "<ESC><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<CR>")
      end
    },
    {
      "phaazon/hop.nvim", -- Easy motion
      config = function()
        require("hop").setup()
        vim.keymap.set("n", "<leader>j", ":HopLine<CR>", { silent = true })
        vim.keymap.set("n", "<leader>w", ":HopWord<CR>", { silent = true })
        vim.keymap.set("n", "<leader>s", ":HopChar1<CR>", { silent = true })
      end
    },
    {
      "tpope/vim-fugitive", -- Git integration
      config = function()
        vim.keymap.set("n", "<leader>gs", ":Git<CR>")
        vim.keymap.set("n", "<leader>gc", ":Git commit<CR>")
        vim.keymap.set("n", "<leader>gp", ":Git push<CR>")
      end
    },
    {
      "windwp/nvim-autopairs", -- Auto pairs
      event = "InsertEnter",
      config = function()
        require("nvim-autopairs").setup()
      end
    },
    {
      "neovim/nvim-lspconfig", -- LSP configuration
      tag = "v0.1.6", -- Stable tag compatible with nvim 0.9.4
      event = "BufReadPre", -- Lazy load on file open
      dependencies = {
        { "williamboman/mason.nvim", tag = "v1.8.0" },
        { "williamboman/mason-lspconfig.nvim", tag = "v1.24.0" },
        { "hrsh7th/nvim-cmp", tag = "v0.0.1" },
        { "hrsh7th/cmp-nvim-lsp", commit = "44b16d11215dce86f253ce0c30949813c0a90765" },
        { "hrsh7th/cmp-buffer", commit = "3022dbc9166796b644a841a02de8dd1cc1d311fa" },
        { "hrsh7th/cmp-path", commit = "91ff86cd9c29299a64f968ebb45846c485725f23" },
        { "L3MON4D3/LuaSnip", tag = "v2.1.0" },
        { "saadparwaiz1/cmp_luasnip", commit = "05a9ab28b53f71d1aece421ef32fee2cb857a843" },
      },
      config = function()
        -- Enhanced mason setup for Windows
        require("mason").setup({
          ui = { 
            border = "rounded",
            icons = {
              package_installed = "✓",
              package_pending = "➜",
              package_uninstalled = "✗"
            }
          },
          install_root_dir = vim.fn.stdpath("data") .. "/mason",
          pip = {
            upgrade_pip = true,
            install_args = {},
          },
          log_level = vim.log.levels.INFO,
          max_concurrent_installers = 4,
          github = {
            download_url_template = "https://github.com/%s/releases/download/%s/%s",
          },
        })
        
        -- Basic lspconfig setup without mason-lspconfig auto-setup
        local lspconfig = require("lspconfig")
        local cmp_nvim_lsp = require("cmp_nvim_lsp")
        local capabilities = cmp_nvim_lsp.default_capabilities()
        
        -- Manual server setup - only if executables exist
        if vim.fn.executable('lua-language-server') == 1 then
          lspconfig.lua_ls.setup({
          capabilities = capabilities,
            settings = {
              Lua = {
                diagnostics = { globals = {'vim'} },
                workspace = { checkThirdParty = false },
              }
            }
          })
        end
        
        if vim.fn.executable('pyright') == 1 then
          lspconfig.pyright.setup({ capabilities = capabilities })
        end
        
        -- LSP keymaps
        vim.keymap.set("n", "gd", vim.lsp.buf.definition)
        vim.keymap.set("n", "K", vim.lsp.buf.hover)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action)
        
        -- Simple completion setup
        local cmp = require("cmp")
        local luasnip = require("luasnip")
        
        cmp.setup({
          snippet = {
            expand = function(args)
              luasnip.lsp_expand(args.body)
            end,
          },
          mapping = cmp.mapping.preset.insert({
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<CR>"] = cmp.mapping.confirm({ select = true }),
            ["<Tab>"] = cmp.mapping(function(fallback)
              if cmp.visible() then
                cmp.select_next_item()
              -- elseif vim.fn["copilot#GetDisplayedSuggestion"]().text ~= "" then
              --   vim.fn.feedkeys(vim.api.nvim_replace_termcodes(vim.fn["copilot#Accept"](), true, true, true), "")
              else
                fallback()
              end
            end, { "i", "s" }),
            ["<S-Tab>"] = cmp.mapping(function(fallback)
              if cmp.visible() then
                cmp.select_prev_item()
              else
                fallback()
              end
            end, { "i", "s" }),
          }),
          sources = {
            { name = "nvim_lsp" },
            { name = "luasnip" },
            { name = "buffer" },
            { name = "path" },
          },
        })
      end
    },
    -- {
    --   "github/copilot.vim", -- GitHub Copilot (commented out - no longer paying for subscription)
    --   event = "InsertEnter",
    --   config = function()
    --     -- Disable default tab mapping to avoid conflicts
    --     vim.g.copilot_no_tab_map = true
    --     vim.g.copilot_assume_mapped = true
    --     vim.g.copilot_tab_fallback = ""
    --     
    --     -- Set up Copilot keymaps after VimEnter to ensure they work
    --     vim.api.nvim_create_autocmd("VimEnter", {
    --       callback = function()
    --         -- Accept suggestion with Ctrl+J (Git Bash friendly)
    --         vim.keymap.set("i", "<C-j>", 'copilot#Accept("\\<CR>")', {
    --           expr = true,
    --           replace_keycodes = false,
    --           silent = true,
    --           desc = "Accept Copilot suggestion"
    --         })
    --         
    --         -- Navigate suggestions
    --         vim.keymap.set("i", "<C-]>", "<Plug>(copilot-next)", { silent = true, desc = "Next Copilot suggestion" })
    --         vim.keymap.set("i", "<C-[>", "<Plug>(copilot-previous)", { silent = true, desc = "Previous Copilot suggestion" })
    --         vim.keymap.set("i", "<C-\\>", "<Plug>(copilot-dismiss)", { silent = true, desc = "Dismiss Copilot suggestion" })
    --       end,
    --     })
    --   end,
    -- },
    {
      "tpope/vim-repeat", -- Repeat plugin commands
    },
    {
      "kevinhwang91/nvim-bqf", -- Better quickfix
      ft = "qf",
    },
    {
      "echasnovski/mini.nvim", -- Mini plugins collection
      config = function()
        require("mini.ai").setup()
        require("mini.cursorword").setup()
        require("mini.indentscope").setup()
        require("mini.starter").setup()
      end
    },
    {
      "mattn/emmet-vim", -- Emmet for HTML/CSS
    },
    {
      "tommcdo/vim-lion", -- Alignment
      config = function()
        vim.g.lion_squeeze_spaces = 1
      end
    },
    -- File tree with improved configuration
    {
      "nvim-tree/nvim-tree.lua",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        vim.g.loaded_netrw = 1
        vim.g.loaded_netrwPlugin = 1
        
        require("nvim-tree").setup({
          sort_by = "case_sensitive",
          view = { 
            width = 35,
            relativenumber = true,
            number = true,
          },
          renderer = { 
            group_empty = true,
            root_folder_label = ":~:s?$?/..?",
            indent_width = 2,
            indent_markers = {
              enable = true,
              inline_arrows = true,
              icons = {
                corner = "└",
                edge = "│",
                item = "│",
                bottom = "─",
                none = " ",
              },
            },
            icons = {
              webdev_colors = true,
              git_placement = "before",
              padding = " ",
              symlink_arrow = " ➛ ",
              show = {
                file = true,
                folder = true,
                folder_arrow = true,
                git = true,
                modified = true,
              },
              glyphs = {
                default = "",
                symlink = "",
                bookmark = "",
                modified = "●",
                folder = {
                  arrow_closed = "",
                  arrow_open = "",
                  default = "",
                  open = "",
                  empty = "",
                  empty_open = "",
                  symlink = "",
                  symlink_open = "",
                },
                git = {
                  unstaged = "✗",
                  staged = "✓",
                  unmerged = "",
                  renamed = "➜",
                  untracked = "★",
                  deleted = "",
                  ignored = "◌",
                },
              },
            },
          },
          filters = { 
            dotfiles = false,
            git_clean = false,
            no_buffer = false,
            custom = { "^.git$" },
          },
          git = {
            enable = true,
            ignore = false,
            show_on_dirs = true,
            show_on_open_dirs = true,
            timeout = 400,
          },
          actions = {
            use_system_clipboard = true,
            change_dir = {
              enable = true,
              global = false,
              restrict_above_cwd = false,
            },
            expand_all = {
              max_folder_discovery = 300,
              exclude = { ".git", "target", "build" },
            },
            open_file = {
              quit_on_open = false,
              resize_window = true,
              window_picker = {
                enable = true,
                picker = "default",
                chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
                exclude = {
                  filetype = { "notify", "packer", "qf", "diff", "fugitive", "fugitiveblame" },
                  buftype = { "nofile", "terminal", "help" },
                },
              },
            },
          },
          live_filter = {
            prefix = "[FILTER]: ",
            always_show_folders = true,
          },
        })
        
        -- File tree keymaps
        vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true, desc = "Toggle file tree" })
        vim.keymap.set("n", "<leader>E", ":NvimTreeFocus<CR>", { silent = true, desc = "Focus file tree" })
        vim.keymap.set("n", "<leader>tf", ":NvimTreeFindFile<CR>", { silent = true, desc = "Find current file in tree" })
        vim.keymap.set("n", "<leader>tc", ":NvimTreeCollapse<CR>", { silent = true, desc = "Collapse file tree" })
      end
    },
    {
      "folke/tokyonight.nvim",
      lazy = false,
      priority = 1000,
      config = function()
        require("tokyonight").setup({
          style = "night",
          light_style = "day",
          transparent = false,
          terminal_colors = true,
          styles = {
            comments = { italic = true },
            keywords = { italic = true },
            functions = {},
            variables = {},
            sidebars = "dark",
            floats = "dark",
          },
          sidebars = { "qf", "help" },
          day_brightness = 0.3,
          hide_inactive_statusline = false,
          dim_inactive = false,
          lualine_bold = false,
        })
        vim.cmd([[colorscheme tokyonight]])
      end
    },
    {
      "nvim-treesitter/nvim-treesitter",
      build = function()
        -- Cross-platform TSUpdate
        if is_windows then
          vim.cmd('TSUpdate')
        else
          require("nvim-treesitter.install").update({ with_sync = true })
        end
      end,
      config = function()
        local status_ok, configs = pcall(require, "nvim-treesitter.configs")
        if not status_ok then
          vim.notify("Failed to load nvim-treesitter.configs", vim.log.levels.ERROR)
          return
        end
        
        configs.setup({
          ensure_installed = { "lua", "vim", "vimdoc", "javascript", "python", "bash", "query" },
          sync_install = false,
          auto_install = false,
          highlight = { 
            enable = true,
            additional_vim_regex_highlighting = false,
            disable = function(lang, buf)
              local max_filesize = 100 * 1024 -- 100 KB
              local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
              if ok and stats and stats.size > max_filesize then
                return true
              end
              -- Disable for very large buffers to prevent out-of-range errors
              local lines = vim.api.nvim_buf_line_count(buf)
              if lines > 10000 then
                return true
              end
            end,
          },
          indent = { 
            enable = true,
            disable = { "python" } -- Python indentation can be problematic
          },
          incremental_selection = {
            enable = true,
            keymaps = {
              init_selection = "gnn",
              node_incremental = "grn",
              scope_incremental = "grc",
              node_decremental = "grm",
            },
          },
        })
      end
    },
    -- Simplified statusline without icons
    {
      "nvim-lualine/lualine.nvim",
      config = function()
        require("lualine").setup({
          options = {
            theme = "tokyonight",
            component_separators = { left = "|", right = "|" },
            section_separators = { left = "", right = "" },
            icons_enabled = false, -- Disable icons to avoid font issues
          },
          sections = {
            lualine_a = {'mode'},
            lualine_b = {'branch', 'diff'},
            lualine_c = {'filename'},
            lualine_x = {'encoding', 'fileformat', 'filetype'},
            lualine_y = {'progress'},
            lualine_z = {'location'}
          },
        })
      end
    },
    -- Oil for file management (simpler than nvim-tree for some use cases)
    {
      'stevearc/oil.nvim',
      config = function()
        require("oil").setup({
          default_file_explorer = false, -- Keep nvim-tree as primary
          view_options = {
            show_hidden = true,
          },
        })
        vim.keymap.set("n", "<leader>o", ":Oil<CR>", { silent = true })
      end
    },
    {
      "lewis6991/gitsigns.nvim",
      config = function()
        require("gitsigns").setup({
          signs = {
            add = { text = "+" },
            change = { text = "~" },
            delete = { text = "_" },
            topdelete = { text = "‾" },
            changedelete = { text = "~" },
          },
          current_line_blame = true,
          current_line_blame_opts = {
            virt_text = true,
            virt_text_pos = "eol",
            delay = 1000,
          },
          on_attach = function(bufnr)
            local gs = package.loaded.gitsigns
            local function map(mode, l, r, opts)
              opts = opts or {}
              opts.buffer = bufnr
              vim.keymap.set(mode, l, r, opts)
            end
            -- Navigation
            map('n', ']c', function()
              if vim.wo.diff then return ']c' end
              vim.schedule(function() gs.next_hunk() end)
              return '<Ignore>'
            end, {expr=true})
            map('n', '[c', function()
              if vim.wo.diff then return '[c' end
              vim.schedule(function() gs.prev_hunk() end)
              return '<Ignore>'
            end, {expr=true})
            -- Actions
            map('n', '<leader>hs', gs.stage_hunk)
            map('n', '<leader>hr', gs.reset_hunk)
            map('v', '<leader>hs', function() gs.stage_hunk {vim.fn.line('.'), vim.fn.line('v')} end)
            map('v', '<leader>hr', function() gs.reset_hunk {vim.fn.line('.'), vim.fn.line('v')} end)
            map('n', '<leader>hS', gs.stage_buffer)
            map('n', '<leader>hu', gs.undo_stage_hunk)
            map('n', '<leader>hR', gs.reset_buffer)
            map('n', '<leader>hp', gs.preview_hunk)
            map('n', '<leader>hb', function() gs.blame_line{full=true} end)
            map('n', '<leader>tb', gs.toggle_current_line_blame)
            map('n', '<leader>hd', gs.diffthis)
            map('n', '<leader>hD', function() gs.diffthis('~') end)
            map('n', '<leader>td', gs.toggle_deleted)
          end
        })
      end
    },
    {
      "tpope/vim-fugitive",
      event = "VeryLazy",
      config = function()
        vim.keymap.set("n", "<leader>gs", ":Git<CR>", { desc = "Git status" })
        vim.keymap.set("n", "<leader>gd", ":Gdiffsplit<CR>", { desc = "Git diff" })
        vim.keymap.set("n", "<leader>gb", ":Git blame<CR>", { desc = "Git blame" })
        vim.keymap.set("n", "<leader>gw", ":Gwrite<CR>", { desc = "Git write (stage)" })
        vim.keymap.set("n", "<leader>gc", ":Git commit<CR>", { desc = "Git commit" })
        vim.keymap.set("n", "<leader>gp", ":Git push<CR>", { desc = "Git push" })
        vim.keymap.set("n", "<leader>gl", ":Git pull<CR>", { desc = "Git pull" })
      end
    },
    {
      "NeogitOrg/neogit",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "sindrets/diffview.nvim",
        "nvim-telescope/telescope.nvim",
      },
      config = function()
        local neogit = require("neogit")
        neogit.setup({
          integrations = {
            telescope = true,
            diffview = true,
          },
        })
        vim.keymap.set("n", "<leader>gg", neogit.open, { desc = "Neogit" })
        vim.keymap.set("n", "<leader>gc", function() neogit.open({ "commit" }) end, { desc = "Neogit commit" })
      end
    },
    {
      "sindrets/diffview.nvim",
      config = function()
        require("diffview").setup({
          use_icons = true,
          enhanced_diff_hl = true,
          key_bindings = {
            disable_defaults = false,
            view = {
              ["<tab>"] = "select_next_entry",
              ["<s-tab>"] = "select_prev_entry",
              ["gf"] = "goto_file",
              ["<C-w><C-f>"] = "goto_file_split",
              ["<C-w>gf"] = "goto_file_tab",
              ["<leader>e"] = "focus_files",
              ["<leader>b"] = "toggle_files",
            },
            file_panel = {
              ["j"] = "next_entry",
              ["<down>"] = "next_entry",
              ["k"] = "prev_entry",
              ["<up>"] = "prev_entry",
              ["<cr>"] = "select_entry",
              ["o"] = "select_entry",
              ["<2-LeftMouse>"] = "select_entry",
              ["-"] = "toggle_stage_entry",
              ["S"] = "stage_all",
              ["U"] = "unstage_all",
              ["X"] = "restore_entry",
              ["R"] = "refresh_files",
              ["L"] = "open_commit_log",
              ["<c-b>"] = "scroll_view(-0.25)",
              ["<c-f>"] = "scroll_view(0.25)",
              ["<tab>"] = "select_next_entry",
              ["<s-tab>"] = "select_prev_entry",
              ["gf"] = "goto_file",
              ["<C-w><C-f>"] = "goto_file_split",
              ["<C-w>gf"] = "goto_file_tab",
              ["i"] = "listing_style",
              ["f"] = "toggle_flatten_dirs",
              ["<leader>e"] = "focus_files",
              ["<leader>b"] = "toggle_files",
            },
          },
        })
        vim.keymap.set("n", "<leader>dv", ":DiffviewOpen<CR>", { desc = "Diffview open" })
        vim.keymap.set("n", "<leader>dc", ":DiffviewClose<CR>", { desc = "Diffview close" })
        vim.keymap.set("n", "<leader>dh", ":DiffviewFileHistory<CR>", { desc = "Diffview file history" })
        vim.keymap.set("n", "<leader>df", ":DiffviewFileHistory %<CR>", { desc = "Diffview current file history" })
      end
    },
    {
      "folke/which-key.nvim",
      event = "VeryLazy",
      config = function()
        require("which-key").setup({
          win = {
            border = "rounded",
            wo = {
              winblend = 0
            }
          },
          layout = {
            height = { min = 4, max = 25 },
            width = { min = 20, max = 50 },
            spacing = 3,
            align = "left"
          },
          show_help = true,
          show_keys = true,
          triggers = {
            { "<auto>", mode = "nxsot" }
          },
        })
      end
    },
    {
      "folke/trouble.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        require("trouble").setup({
          position = "bottom",
          height = 10,
          width = 50,
          icons = false,
          mode = "workspace_diagnostics",
          fold_open = "v",
          fold_closed = ">",
          group = true,
          padding = true,
          action_keys = {
            close = "q",
            cancel = "<esc>",
            refresh = "r",
            jump = { "<cr>", "<tab>" },
            open_split = { "<c-x>" },
            open_vsplit = { "<c-v>" },
            open_tab = { "<c-t>" },
            jump_close = {"o"},
            toggle_mode = "m",
            toggle_preview = "P",
            hover = "K",
            preview = "p",
            close_folds = {"zM", "zm"},
            open_folds = {"zR", "zr"},
            toggle_fold = {"zA", "za"},
            previous = "k",
            next = "j"
          },
        })
        vim.keymap.set("n", "<leader>xx", ":Trouble<CR>", { silent = true, desc = "Toggle Trouble" })
        vim.keymap.set("n", "<leader>xw", ":Trouble workspace_diagnostics<CR>", { silent = true, desc = "Workspace diagnostics" })
        vim.keymap.set("n", "<leader>xd", ":Trouble document_diagnostics<CR>", { silent = true, desc = "Document diagnostics" })
        vim.keymap.set("n", "<leader>xl", ":Trouble loclist<CR>", { silent = true, desc = "Location list" })
        vim.keymap.set("n", "<leader>xq", ":Trouble quickfix<CR>", { silent = true, desc = "Quickfix" })
      end
    },
    {
      "akinsho/toggleterm.nvim",
      version = "*",
      config = function()
        local ok, toggleterm = pcall(require, "toggleterm")
        if not ok then return end
        toggleterm.setup({
          -- Quick toggle
          open_mapping = [[<c-\>]],
          insert_mappings = true,
          terminal_mappings = true,
          start_in_insert = true,
          persist_size = true,
          shade_terminals = true,
          close_on_exit = true,
          -- Use floating by default with roomy size
          direction = "float",
          size = 20,
          float_opts = {
            border = "curved",
            winblend = 0,
            width = function()
              return math.floor(vim.o.columns * 0.9)
            end,
            height = function()
              return math.floor(vim.o.lines * 0.85)
            end,
          },
          -- Respect user's shell; we set platform-specific default below
          shell = vim.o.shell,
        })

        -- Lazygit integration via ToggleTerm (no extra plugin required)
        local Terminal = require('toggleterm.terminal').Terminal
        local lazygit = Terminal:new({
          cmd = "lazygit",
          dir = "git_dir",
          direction = "float",
          hidden = true,
          on_open = function(term)
            -- Make <Esc> drop to Normal, then 'q' quits lazygit and hides terminal
            vim.api.nvim_buf_set_keymap(term.bufnr, 't', '<Esc>', [[<C-\><C-n>]], { noremap = true, silent = true })
          end,
        })

        function _LAZYGIT_TOGGLE()
          lazygit:toggle()
        end

        vim.keymap.set('n', '<leader>lg', '<cmd>lua _LAZYGIT_TOGGLE()<CR>', { desc = 'LazyGit (float)' })
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
            -- Use Ctrl+n/p for completion navigation instead of Tab
            ["<C-n>"] = cmp.mapping.select_next_item(),
            ["<C-p>"] = cmp.mapping.select_prev_item(),
            ["<CR>"] = cmp.mapping.confirm({ select = true }),
            ["<C-Space>"] = cmp.mapping.complete(),
            -- Disable Tab for cmp to avoid conflict with Copilot
            ["<Tab>"] = cmp.mapping(function(fallback)
              fallback()
            end, { "i", "s" }),
            ["<S-Tab>"] = cmp.mapping(function(fallback)
              fallback()
            end, { "i", "s" }),
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
  install = { 
    colorscheme = { "tokyonight" },
    missing = true, -- Install missing plugins on startup
  },
  checker = { 
    enabled = false, -- Disable automatic update checking
    notify = false,  -- Don't notify about updates
  },
  change_detection = {
    enabled = false, -- Disable config change detection
    notify = false,  -- Don't notify about config changes
  },
  performance = {
    cache = {
      enabled = true,
    },
    reset_packpath = true,
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
        "netrw",
        "netrwPlugin",
        "netrwSettings",
        "netrwFileHandlers",
      },
    },
  },
})

-- Key mappings from vimrc (set after plugins to avoid conflicts)
vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode with jj" })
vim.keymap.set("n", ";", ":", { desc = "Use semicolon for command mode" })
vim.keymap.set("n", ":", ";", { desc = "Use colon for repeat find" })

-- Copilot configuration (after plugins are loaded) - commented out, no longer paying for subscription
-- vim.g.copilot_no_tab_map = true
-- vim.g.copilot_assume_mapped = true
-- 
-- -- Map Tab to accept Copilot suggestions
-- vim.keymap.set("i", "<Tab>", 'copilot#Accept("\\<CR>")', {
--   expr = true,
--   replace_keycodes = false,
--   silent = true
-- })
-- -- Alternative mapping
-- vim.keymap.set("i", "<C-J>", 'copilot#Accept("\\<CR>")', {
--   expr = true,
--   replace_keycodes = false,
--   silent = true
-- })

-- Use a different key for fold toggle since space is leader
vim.keymap.set("n", "za", "za", { desc = "Toggle fold" })
-- Additional keymaps for better Git Bash compatibility
vim.keymap.set("n", "<leader>h", ":nohlsearch<CR>", { silent = true })

-- Window navigation (using Alt instead of Ctrl to avoid conflicts)
vim.keymap.set("n", "<A-h>", "<C-w>h")
vim.keymap.set("n", "<A-j>", "<C-w>j")
vim.keymap.set("n", "<A-k>", "<C-w>k")
vim.keymap.set("n", "<A-l>", "<C-w>l")

-- Quick save and quit
vim.keymap.set("n", "<leader>w", ":w<CR>")
vim.keymap.set("n", "<leader>q", ":q<CR>")
vim.keymap.set("n", "<leader>x", ":x<CR>")

-- Buffer navigation
vim.keymap.set("n", "<leader>bn", ":bnext<CR>")
vim.keymap.set("n", "<leader>bp", ":bprev<CR>")
vim.keymap.set("n", "<leader>bd", ":bdelete<CR>")

-- Common vim shortcuts
vim.keymap.set("n", "Y", "y$") -- Yank to end of line
vim.keymap.set("n", "n", "nzzzv") -- Keep search centered
vim.keymap.set("n", "N", "Nzzzv") -- Keep search centered
vim.keymap.set("n", "J", "mzJ`z") -- Keep cursor position when joining lines
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv") -- Move selected lines down
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv") -- Move selected lines up

-- Better search and replace
vim.keymap.set("n", "<leader>sr", ":%s/\\<<C-r><C-w>\\>/<C-r><C-w>/gI<Left><Left><Left>") -- Replace word under cursor
vim.keymap.set("n", "<leader>S", ":%s/") -- Quick substitute

-- Better navigation
vim.keymap.set("n", "<C-d>", "<C-d>zz") -- Keep cursor centered when jumping
vim.keymap.set("n", "<C-u>", "<C-u>zz") -- Keep cursor centered when jumping
vim.keymap.set("n", "*", "*zz") -- Keep cursor centered when searching
vim.keymap.set("n", "#", "#zz") -- Keep cursor centered when searching
vim.keymap.set("n", "k", "gk", { desc = "Move up by display line" })
vim.keymap.set("n", "j", "gj", { desc = "Move down by display line" })

-- Line swapping with Alt+Up/Down
vim.keymap.set("n", "<A-Up>", ":m .-2<CR>==", { desc = "Move line up" })
vim.keymap.set("n", "<A-Down>", ":m .+1<CR>==", { desc = "Move line down" })
vim.keymap.set("i", "<A-Up>", "<Esc>:m .-2<CR>==gi", { desc = "Move line up in insert mode" })
vim.keymap.set("i", "<A-Down>", "<Esc>:m .+1<CR>==gi", { desc = "Move line down in insert mode" })
vim.keymap.set("v", "<A-Up>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
vim.keymap.set("v", "<A-Down>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })

-- Git Bash friendly shortcuts
vim.keymap.set("n", "<C-s>", ":w<CR>") -- Save with Ctrl+S
vim.keymap.set("i", "<C-s>", "<Esc>:w<CR>a") -- Save in insert mode
vim.keymap.set("n", "<C-z>", "u") -- Undo with Ctrl+Z
vim.keymap.set("i", "<C-z>", "<Esc>ua") -- Undo in insert mode
vim.keymap.set("n", "<C-y>", "<C-r>") -- Redo with Ctrl+Y
vim.keymap.set("i", "<C-y>", "<Esc><C-r>a") -- Redo in insert mode

-- Tab navigation
vim.keymap.set("n", "<C-Right>", ":tabnext<CR>", { desc = "Next tab" })
vim.keymap.set("n", "<C-Left>", ":tabprevious<CR>", { desc = "Previous tab" })
vim.keymap.set("n", "<C-t>", ":tabnew<CR>", { desc = "New tab" })

-- Create blank lines
vim.keymap.set("n", "zj", "o<Esc>", { desc = "Create blank line below" })
vim.keymap.set("n", "zk", "O<Esc>", { desc = "Create blank line above" })

-- Terminal mode escape
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>")

-- Smart Git-based file auto-reload with automatic merging
-- This intelligently merges external changes with local changes
-- Similar to "accept both changes" in git conflicts
local smart_reload_ok, smart_reload = pcall(require, 'smart-reload')
if smart_reload_ok then
  smart_reload.setup()
  vim.notify('Smart reload enabled - auto-merges external changes', vim.log.levels.INFO)
else
  -- Fallback to basic auto-reload if smart-reload module not found
  vim.api.nvim_create_augroup('AutoReload', { clear = true })
  
  vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'CursorHoldI' }, {
    group = 'AutoReload',
    pattern = '*',
    callback = function()
      if vim.fn.mode() ~= 'c' and vim.fn.getcmdwintype() == '' then
        vim.cmd('checktime')
      end
    end,
  })
  
  vim.api.nvim_create_autocmd('FileChangedShell', {
    group = 'AutoReload',
    pattern = '*',
    callback = function(args)
      local bufnr = args.buf
      local modified = vim.bo[bufnr].modified
      
      if not modified then
        vim.v.fcs_choice = 'reload'
      else
        vim.v.fcs_choice = 'keep'
        vim.notify('File changed externally but you have local changes - keeping local', vim.log.levels.WARN)
      end
    end,
  })
end

-- Watch for file changes more frequently
vim.opt.updatetime = 1000  -- Check for changes every 1000ms (more reasonable)
vim.opt.autoread = true   -- Enable autoread

-- Performance optimizations for Windows (guarded)
if is_windows then
  vim.opt.shell = "powershell"
  vim.opt.shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;"
  vim.opt.shellredir = "-RedirectStandardOutput %s -NoNewWindow -Wait"
  vim.opt.shellpipe = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
  vim.opt.shellquote = ""
  vim.opt.shellxquote = ""
end

-- Auto-format on save for specific filetypes (optional)
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.lua", "*.py", "*.js", "*.ts", "*.jsx", "*.tsx" },
  callback = function()
    if vim.lsp.buf.format then
      vim.lsp.buf.format({ async = false })
    end
  end,
})
