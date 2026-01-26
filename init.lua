-- ~/.config/nvim/init.lua

-- Set leader key early
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load user configurations
require("user.options")
require("user.keymaps")
require("user.autocommands")
require("user.commands")

-- Setup plugins
require("lazy").setup({
  -- Tree file browser
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("nvim-tree").setup({
        sort_by = "case_sensitive",
        view = {
          width = 35,
          side = "left",
        },
        renderer = {
          group_empty = true,
          icons = {
            show = {
              file = true,
              folder = true,
              folder_arrow = true,
              git = true,
            },
          },
        },
        filters = {
          dotfiles = false,
          custom = { "node_modules", ".git", ".DS_Store" },
        },
        git = {
          enable = true,
          ignore = false,
          timeout = 400,
        },
        actions = {
          open_file = {
            quit_on_open = false,
            resize_window = true,
          },
        },
      })
    end,
  },

  -- Telescope fuzzy finder with additional extensions
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.2.0',
    dependencies = { 
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-fzf-native.nvim',
      'nvim-telescope/telescope-live-grep-args.nvim',
      'nvim-telescope/telescope-file-browser.nvim',
      'debugloop/telescope-undo.nvim',
    },
    config = function()
      local telescope = require('telescope')
      local actions = require('telescope.actions')
      local builtin = require('telescope.builtin')
      
      telescope.setup({
        defaults = {
          prompt_prefix = "  ",
          selection_caret = "❯ ",
          path_display = { "smart" },
          sorting_strategy = "ascending",
          layout_strategy = "flex",
          file_ignore_patterns = {
            "node_modules/.*",
            "%.git/.*",
            "%.DS_Store",
            "target/.*",
            "build/.*",
            "dist/.*",
            "__pycache__/.*",
            "%.pyc",
            "%.o",
            "%.a",
            "%.class",
            "%.pdf",
            "%.mkv",
            "%.mp4",
            "%.zip",
          },
          mappings = {
            i = {
              ["<C-h>"] = "which_key",
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
              ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
              ["<C-x>"] = actions.select_horizontal,
              ["<C-v>"] = actions.select_vertical,
              ["<C-t>"] = actions.select_tab,
              ["<C-u>"] = actions.preview_scrolling_up,
              ["<C-d>"] = actions.preview_scrolling_down,
              ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
              ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
              ["<C-/>>"] = actions.which_key,
              ["<C-_>"] = actions.which_key, -- terminals send C-/ as C-_
              ["<Esc>"] = actions.close,
            },
            n = {
              ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
              ["q"] = actions.close,
              ["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
              ["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
            }
          },
          layout_config = {
            horizontal = {
              prompt_position = "top",
              preview_width = 0.55,
            },
            vertical = {
              mirror = false,
            },
            width = 0.87,
            height = 0.80,
            preview_cutoff = 120,
          },
        },
        pickers = {
          find_files = {
            hidden = true,
            follow = true,
            -- Use ripgrep to list files (faster than find)
            find_command = { "rg", "--files", "--hidden", "--follow", "--glob", "!.git/*", "--glob", "!node_modules/*", "--glob", "!target/*" },
          },
          live_grep = {
            theme = "ivy",
          },
          buffers = {
            sort_lastused = true,
            theme = "dropdown",
            previewer = false,
            initial_mode = "normal",
            mappings = {
              i = {
                ["<C-w>"] = actions.delete_buffer,
              },
              n = {
                ["dd"] = actions.delete_buffer,
              },
            },
          },
        },
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
          },
        }
      })
      
      -- Load extensions
      telescope.load_extension('fzf')
      pcall(telescope.load_extension, 'file_browser')
      pcall(telescope.load_extension, 'undo')
    end,
  },

  -- FZF native for better sorting
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'make'
  },

  -- Formatting with external tools (ruff, prettier, gofmt, etc.)
  {
    'stevearc/conform.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local conform = require('conform')
      conform.setup({
        formatters_by_ft = {
          lua = { 'stylua' },
          python = function(bufnr)
            if require("conform").get_formatter_info("ruff_format", bufnr).available then
              return { "ruff_format", "ruff_fix" }
            else
              return { "black" }
            end
          end,
          javascript = { 'prettierd', 'prettier', stop_after_first = true },
          typescript = { 'prettierd', 'prettier', stop_after_first = true },
          javascriptreact = { 'prettierd', 'prettier', stop_after_first = true },
          typescriptreact = { 'prettierd', 'prettier', stop_after_first = true },
          json = { 'prettierd', 'prettier', stop_after_first = true },
          jsonc = { 'prettierd', 'prettier', stop_after_first = true },
          markdown = { 'prettierd', 'prettier', stop_after_first = true },
          html = { 'prettierd', 'prettier', stop_after_first = true },
          css = { 'prettierd', 'prettier', stop_after_first = true },
          scss = { 'prettierd', 'prettier', stop_after_first = true },
          yaml = { 'prettierd', 'prettier', stop_after_first = true },
          toml = { 'taplo' },
          sh = { 'shfmt' },
          bash = { 'shfmt' },
          go = { 'goimports', 'gofmt' },
          rust = { 'rustfmt' },
        },
        format_on_save = false,
        notify_on_error = true,
        default_format_opts = {
          lsp_format = 'fallback',
        },
      })

      -- Keymaps: Space+F as primary, with additional fallbacks
      local fmt = function()
        require('conform').format({ async = true, lsp_fallback = true })
      end
      vim.keymap.set({ 'n', 'v' }, '<leader>F', fmt, { desc = 'Format document/selection (Conform)' })
      vim.keymap.set({ 'n', 'v' }, '<C-S-f>', fmt, { desc = 'Format document/selection (Conform)' })
    end,
  },

  -- GitHub Copilot (commented out - no longer paying for subscription)
  -- {
  --   "github/copilot.vim",
  --   config = function()
  --     vim.g.copilot_no_tab_map = true
  --     vim.g.copilot_assume_mapped = true
  --     vim.api.nvim_set_keymap("i", "<C-J>", 'copilot#Accept("<CR>")', { silent = true, expr = true })
  --     vim.api.nvim_set_keymap("i", "<C-L>", 'copilot#AcceptWord()', { silent = true, expr = true })
  --     vim.api.nvim_set_keymap("i", "<C-H>", 'copilot#Previous()', { silent = true, expr = true })
  --     vim.api.nvim_set_keymap("i", "<C-K>", 'copilot#Next()', { silent = true, expr = true })
  --   end
  -- },

  -- Status line
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup({
        options = {
          theme = 'auto',
          component_separators = { left = '|', right = '|'},
          section_separators = { left = '', right = ''},
          globalstatus = true,
        },
        sections = {
          lualine_a = {'mode'},
          lualine_b = {'branch', 'diff', 'diagnostics'},
          lualine_c = {
            {
              'filename',
              file_status = true,
              newfile_status = false,
              path = 1,
            }
          },
          lualine_x = {'encoding', 'fileformat', 'filetype'},
          lualine_y = {'progress'},
          lualine_z = {'location'}
        },
        extensions = {'nvim-tree', 'quickfix', 'fugitive'}
      })
    end,
  },

  -- Syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { 
          "c", "lua", "vim", "vimdoc", "query", "python", "javascript", 
          "typescript", "html", "css", "json", "yaml", "toml", "bash",
          "go", "rust", "cpp", "java", "php", "ruby", "dockerfile",
          "markdown", "sql", "regex", "tsx"
        },
        sync_install = false,
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
          use_languagetree = true,
          disable = function(lang, buf)
            local max_filesize = 100 * 1024 -- 100 KB
            local ok, stats = pcall((vim.uv or vim.loop).fs_stat, vim.api.nvim_buf_get_name(buf))
            if ok and stats and stats.size > max_filesize then
              return true
            end
          end,
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
        indent = {
          enable = true
        },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
            },
          },
        },
      })
      
      -- Handle TreeSitter highlighting errors - comprehensive error suppression
      local ts_error_group = vim.api.nvim_create_augroup("TreesitterErrorRecovery", { clear = true })
      
      -- Suppress treesitter extmark errors by overriding error output
      local function suppress_ts_errors()
        local orig_notify = vim.notify
        vim.notify = function(msg, level, opts)
          if type(msg) == "string" and 
             (msg:match("Invalid 'end_row': out of range") or 
              msg:match("treesitter") or 
              msg:match("highlighter.lua")) then
            return -- Suppress treesitter errors
          end
          return orig_notify(msg, level, opts)
        end
      end
      
      -- Recovery on buffer events
      vim.api.nvim_create_autocmd({"BufWritePost", "BufEnter", "TextChanged"}, {
        group = ts_error_group,
        callback = function(args)
          local buf = args.buf
          if vim.treesitter.highlighter and vim.treesitter.highlighter.active[buf] then
            local ok, _ = pcall(vim.treesitter.get_parser, buf)
            if not ok then
              vim.schedule(function()
                pcall(vim.treesitter.stop, buf)
                pcall(vim.treesitter.start, buf)
              end)
            end
          end
        end,
      })
      
      -- Apply error suppression
      suppress_ts_errors()
    end,
  },

  -- Git integration
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require('gitsigns').setup({
        signs = {
          add          = { text = '+' },
          change       = { text = '~' },
          delete       = { text = '_' },
          topdelete    = { text = '‾' },
          changedelete = { text = '~' },
          untracked    = { text = '┆' },
        },
        current_line_blame = true,
        current_line_blame_opts = {
          delay = 300,
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
          map('n', '<leader>hS', gs.stage_buffer)
          map('n', '<leader>hu', gs.undo_stage_hunk)
          map('n', '<leader>hR', gs.reset_buffer)
          map('n', '<leader>hp', gs.preview_hunk)
          map('n', '<leader>hb', function() gs.blame_line{full=true} end)
          map('n', '<leader>hd', gs.diffthis)
        end
      })
    end,
  },

  -- LSP Configuration
  {
    'neovim/nvim-lspconfig',
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'hrsh7th/cmp-nvim-lsp',
    },
    config = function()
      require('mason').setup({
        ui = {
          border = 'rounded'
        }
      })
      
      require('mason-lspconfig').setup({
        ensure_installed = {
          'lua_ls',
          'pyright',
          'ts_ls', 
          'html',
          'cssls',
          'jsonls',
          'yamlls',
          'bashls',
          'gopls',
          'rust_analyzer',
        },
        automatic_installation = true,
      })
      
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      local lspconfig = require('lspconfig')
      
      -- Load optimized LSP configuration
      local lsp_optimized = require('user.lsp-optimized')
      
      -- Setup auto-shutdown for idle LSP servers
      lsp_optimized.setup_lsp_timeout()
      
      -- Configure each LSP server
      local servers = {
        lua_ls = {
          settings = {
            Lua = {
              runtime = { version = 'LuaJIT' },
              diagnostics = { globals = {'vim'} },
              workspace = {
                library = vim.api.nvim_get_runtime_file("", true),
                checkThirdParty = false,
              },
              telemetry = { enable = false },
            },
          },
        },
        pyright = {},
        -- ts_ls is configured separately with optimizations
        html = {},
        cssls = {},
        jsonls = {},
        yamlls = {},
        bashls = {},
        gopls = {},
        rust_analyzer = {},
      }
      
      for server, config in pairs(servers) do
        config.capabilities = capabilities
        lspconfig[server].setup(config)
      end
      
      -- Setup optimized TypeScript LSP
      lsp_optimized.setup_typescript()
      
      -- Global mappings
      vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float)
      vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
      vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
      vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)
      
      -- LSP attach keymaps
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('UserLspConfig', {}),
        callback = function(ev)
          local opts = { buffer = ev.buf }
          vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
          vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
          vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
          vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, opts)
          vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts)
          vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, opts)
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
          vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
          vim.keymap.set('n', '<leader>f', function()
            vim.lsp.buf.format { async = true }
          end, opts)
        end,
      })
    end,
  },

  -- Mason for LSP server management
  {
    'williamboman/mason.nvim',
  },
  {
    'williamboman/mason-lspconfig.nvim',
  },
  -- Ensure formatters/linters via Mason
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    dependencies = { 'williamboman/mason.nvim' },
    config = function()
      require('mason').setup()
      require('mason-tool-installer').setup({
        ensure_installed = {
          -- Lua
          'stylua',
          -- Python
          'ruff',
          -- JS/TS/JSON/Markdown/YAML/CSS/HTML
          'prettier',
          -- Shell
          'shfmt',
          -- Go
          'gofumpt', 'goimports',
          -- Rust
          'rustfmt',
          -- TOML
          'taplo',
        },
        auto_update = true,
        run_on_start = true,
      })
    end,
  },

  -- Autocompletion
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-cmdline',
      'L3MON4D3/LuaSnip',
      'saadparwaiz1/cmp_luasnip',
      'rafamadriz/friendly-snippets',
    },
    config = function()
      local cmp = require('cmp')
      local luasnip = require('luasnip')
      
      require('luasnip.loaders.from_vscode').lazy_load()
      
      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
          ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              -- Let Tab pass through for Copilot
              local copilot_keys = vim.fn['copilot#Accept']()
              if copilot_keys ~= '' then
                vim.api.nvim_feedkeys(copilot_keys, 'i', true)
              else
                fallback()
              end
            end
          end, { 'i', 's' }),
          ['<S-Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'path' },
        }, {
          { name = 'buffer' },
        }),
        formatting = {
          format = function(entry, vim_item)
            vim_item.menu = ({
              nvim_lsp = "[LSP]",
              luasnip = "[Snippet]",
              buffer = "[Buffer]",
              path = "[Path]",
            })[entry.source.name]
            return vim_item
          end,
        },
      })
      
      -- Command line completion
      cmp.setup.cmdline({ '/', '?' }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = 'buffer' }
        }
      })
      
      cmp.setup.cmdline(':', {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = 'path' }
        }, {
          { name = 'cmdline' }
        })
      })
    end,
  },

  -- Comment toggling
  {
    'numToStr/Comment.nvim',
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require('Comment').setup()
    end,
  },

  -- Auto pairs
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    config = function()
      require('nvim-autopairs').setup({
        check_ts = true,
        ts_config = {
          lua = {'string'},
          javascript = {'template_string'},
          java = false,
        }
      })
      
      local cmp_autopairs = require('nvim-autopairs.completion.cmp')
      local cmp = require('cmp')
      cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done())
    end,
  },

  -- Indent guides
  {
    'lukas-reineke/indent-blankline.nvim',
    main = "ibl",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("ibl").setup({
        indent = {
          char = "│",
        },
        scope = {
          enabled = true,
        },
      })
    end,
  },

  -- Color scheme
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    config = function()
      require('catppuccin').setup({
        flavour = "mocha",
        background = {
          light = "latte",
          dark = "mocha",
        },
        transparent_background = false,
        show_end_of_buffer = false,
        term_colors = false,
        dim_inactive = {
          enabled = false,
          shade = "dark",
          percentage = 0.15,
        },
        integrations = {
          cmp = true,
          gitsigns = true,
          nvimtree = true,
          telescope = true,
          treesitter = true,
          mason = true,
        },
      })
      vim.cmd.colorscheme "catppuccin"
    end,
  },

  -- Which-key for keybinding help
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    config = function()
      local wk = require("which-key")
      wk.setup({
        plugins = {
          marks = true,
          registers = true,
          spelling = {
            enabled = true,
            suggestions = 20,
          },
        },
      })
      
      -- Register key mappings using new spec format (v3 compatible)
      wk.add({
        { "<leader>f", group = "file/find" },
        { "<leader>g", group = "git" },
        { "<leader>h", group = "git hunks" },
        { "<leader>w", group = "workspace" },
        { "<leader>c", group = "code" },
        { "<leader>r", group = "rename" },
      })
    end,
  },

  -- Terminal integration
  {
    'akinsho/toggleterm.nvim',
    version = "*",
    config = function()
      require("toggleterm").setup({
        size = 20,
        open_mapping = [[<c-\>]],
        hide_numbers = true,
        shade_filetypes = {},
        shade_terminals = true,
        shading_factor = 2,
        start_in_insert = true,
        insert_mappings = true,
        persist_size = true,
        direction = "float",
        close_on_exit = true,
        shell = vim.o.shell,
        float_opts = {
          border = "curved",
          winblend = 0,
          highlights = {
            border = "Normal",
            background = "Normal",
          },
        },
      })
    end,
  },

  -- Buffer management
  {
    'akinsho/bufferline.nvim',
    version = "*",
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
      require("bufferline").setup({
        options = {
          numbers = "none",
          close_command = "bdelete! %d",
          right_mouse_command = "bdelete! %d",
          left_mouse_command = "buffer %d",
          middle_mouse_command = nil,
          indicator = {
            icon = '▎',
            style = 'icon',
          },
          buffer_close_icon = '',
          modified_icon = '●',
          close_icon = '',
          left_trunc_marker = '',
          right_trunc_marker = '',
          max_name_length = 30,
          max_prefix_length = 30,
          tab_size = 21,
          diagnostics = "nvim_lsp",
          diagnostics_update_in_insert = false,
          offsets = {
            {
              filetype = "NvimTree",
              text = "File Explorer",
              text_align = "left",
              separator = true
            }
          },
          show_buffer_icons = true,
          show_buffer_close_icons = true,
          show_close_icon = true,
          show_tab_indicators = true,
          persist_buffer_sort = true,
          separator_style = "slant",
          enforce_regular_tabs = true,
          always_show_bufferline = true,
        },
      })
    end,
  },

  -- Multi-cursor editing
  {
    'mg979/vim-visual-multi',
    branch = 'master',
    init = function()
      -- Use explicit mappings to avoid conflicts with <C-n>
      vim.g.VM_default_mappings = 0
      vim.g.VM_leader = ','
      vim.g.VM_maps = {
        -- Start/select next occurrence (Alt-n)
        ["Find Under"] = "<A-n>",
        ["Find Subword Under"] = "<A-n>",
        -- Select all occurrences (Alt-a)
        ["Select All"] = "<A-a>",
        -- Add cursor above/below (Alt-Up/Alt-Down)
        ["Add Cursor Up"] = "<A-Up>",
        ["Add Cursor Down"] = "<A-Down>",
        -- Extend/shrink region with Alt-h/l in visual-multi mode
        ["Increase Selection"] = ",+",
        ["Decrease Selection"] = ",-",
        -- Exit visual-multi
        ["Quit VM Mode"] = "<Esc>",
      }
    end,
  },
})

-- Enhanced Key mappings
vim.api.nvim_set_keymap('n', '<C-n>', '<cmd>NvimTreeToggle<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>e', '<cmd>NvimTreeFocus<CR>', { noremap = true, silent = true })

-- Telescope mappings - Enhanced fzf-style navigation
-- File navigation
vim.api.nvim_set_keymap('n', '<leader>ff', '<cmd>Telescope find_files<CR>', { noremap = true, silent = true, desc = "Find files" })
vim.api.nvim_set_keymap('n', '<C-p>', '<cmd>lua require("telescope.builtin").find_files({ cwd = vim.fn.getcwd() })<CR>', { noremap = true, silent = true, desc = "Find files (Quick)" })
vim.api.nvim_set_keymap('n', '<leader>fg', '<cmd>Telescope live_grep<CR>', { noremap = true, silent = true, desc = "Live grep" })
vim.api.nvim_set_keymap('n', '<leader>fw', '<cmd>Telescope grep_string<CR>', { noremap = true, silent = true, desc = "Find word under cursor" })
vim.api.nvim_set_keymap('n', '<leader>fb', '<cmd>Telescope buffers<CR>', { noremap = true, silent = true, desc = "Buffers" })
vim.api.nvim_set_keymap('n', '<leader>fh', '<cmd>Telescope help_tags<CR>', { noremap = true, silent = true, desc = "Help tags" })
vim.api.nvim_set_keymap('n', '<leader>fr', '<cmd>Telescope oldfiles<CR>', { noremap = true, silent = true, desc = "Recent files" })
vim.api.nvim_set_keymap('n', '<leader>fc', '<cmd>Telescope commands<CR>', { noremap = true, silent = true, desc = "Commands" })
vim.api.nvim_set_keymap('n', '<leader>fk', '<cmd>Telescope keymaps<CR>', { noremap = true, silent = true, desc = "Keymaps" })
vim.api.nvim_set_keymap('n', '<leader>ft', '<cmd>Telescope treesitter<CR>', { noremap = true, silent = true, desc = "Treesitter symbols" })

-- Symbol search (@ notation support)
vim.api.nvim_set_keymap('n', '<leader>fs', '<cmd>Telescope lsp_document_symbols<CR>', { noremap = true, silent = true, desc = "Document symbols" })
vim.api.nvim_set_keymap('n', '<leader>fS', '<cmd>Telescope lsp_dynamic_workspace_symbols<CR>', { noremap = true, silent = true, desc = "Workspace symbols" })
vim.api.nvim_set_keymap('n', '<leader>@', '<cmd>Telescope lsp_document_symbols<CR>', { noremap = true, silent = true, desc = "Document symbols (@)" })
vim.api.nvim_set_keymap('n', '<leader>@@', '<cmd>Telescope lsp_dynamic_workspace_symbols<CR>', { noremap = true, silent = true, desc = "All symbols (@@)" })

-- Git integration
vim.api.nvim_set_keymap('n', '<leader>gc', '<cmd>Telescope git_commits<CR>', { noremap = true, silent = true, desc = "Git commits" })
vim.api.nvim_set_keymap('n', '<leader>gb', '<cmd>Telescope git_branches<CR>', { noremap = true, silent = true, desc = "Git branches" })
vim.api.nvim_set_keymap('n', '<leader>gs', '<cmd>Telescope git_status<CR>', { noremap = true, silent = true, desc = "Git status" })
vim.api.nvim_set_keymap('n', '<leader>gS', '<cmd>Telescope git_stash<CR>', { noremap = true, silent = true, desc = "Git stash" })

-- Advanced navigation
vim.api.nvim_set_keymap('n', '<leader>/', '<cmd>Telescope current_buffer_fuzzy_find<CR>', { noremap = true, silent = true, desc = "Search in buffer" })
vim.api.nvim_set_keymap('n', '<leader>?', '<cmd>Telescope search_history<CR>', { noremap = true, silent = true, desc = "Search history" })
vim.api.nvim_set_keymap('n', '<leader>fm', '<cmd>Telescope marks<CR>', { noremap = true, silent = true, desc = "Marks" })
vim.api.nvim_set_keymap('n', '<leader>fj', '<cmd>Telescope jumplist<CR>', { noremap = true, silent = true, desc = "Jumplist" })
vim.api.nvim_set_keymap('n', '<leader>fd', '<cmd>Telescope diagnostics<CR>', { noremap = true, silent = true, desc = "Diagnostics" })

-- Quick method/function navigation
vim.api.nvim_set_keymap('n', 'gm', '<cmd>Telescope lsp_document_symbols symbols=method,function<CR>', { noremap = true, silent = true, desc = "Go to method" })
vim.api.nvim_set_keymap('n', 'gM', '<cmd>Telescope lsp_dynamic_workspace_symbols symbols=method,function<CR>', { noremap = true, silent = true, desc = "Go to method (workspace)" })

-- Buffer navigation
vim.api.nvim_set_keymap('n', '<Tab>', '<cmd>BufferLineCycleNext<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<S-Tab>', '<cmd>BufferLineCyclePrev<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>bd', '<cmd>bdelete<CR>', { noremap = true, silent = true })

-- Quick save and quit
vim.api.nvim_set_keymap('n', '<leader>w', '<cmd>w<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>q', '<cmd>q<CR>', { noremap = true, silent = true })

-- Split navigation
vim.api.nvim_set_keymap('n', '<C-h>', '<C-w>h', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-j>', '<C-w>j', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-k>', '<C-w>k', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-l>', '<C-w>l', { noremap = true, silent = true })

-- Split management
vim.api.nvim_set_keymap('n', '<leader>sv', '<cmd>vsplit<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>sh', '<cmd>split<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>sc', '<cmd>close<CR>', { noremap = true, silent = true })

-- Clear search highlighting
vim.api.nvim_set_keymap('n', '<leader>nh', '<cmd>nohl<CR>', { noremap = true, silent = true })
