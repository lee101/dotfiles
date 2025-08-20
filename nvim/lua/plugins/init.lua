-- Main plugins configuration
return {
  -- Colorscheme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme "catppuccin-mocha"
    end,
  },

  -- Mini icons (for which-key compatibility)
  {
    "echasnovski/mini.icons",
    version = false,
    config = function()
      require("mini.icons").setup()
    end,
  },

  -- File explorer
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("nvim-tree").setup({
        view = {
          width = 30,
        },
        renderer = {
          group_empty = true,
        },
      })
      vim.keymap.set('n', '<C-j>', '<Cmd>NvimTreeToggle<CR>', { noremap = true, silent = true })
      vim.keymap.set('n', '<leader>e', '<Cmd>NvimTreeToggle<CR>', { noremap = true, silent = true, desc = "Toggle file tree" })
    end,
  },

  -- Statusline
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup({
        options = {
          theme = 'catppuccin',
          component_separators = { left = '', right = ''},
          section_separators = { left = '', right = ''},
        },
      })
    end,
  },

  -- Fuzzy finder
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.5',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local builtin = require('telescope.builtin')
      vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
      vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
      vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
      vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
    end,
  },

  -- Treesitter for syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        auto_install = true,
        ensure_installed = {
          "lua", "vim", "vimdoc", "query",
          "javascript", "typescript", "tsx",
          "python", "go", "rust",
          "html", "css", "json", "yaml",
          "markdown", "markdown_inline",
          "bash", "dockerfile"
        },
        highlight = {
          enable = true,
          -- Disable error notifications for highlighting
          disable = function(lang, buf)
            -- You can add specific conditions here if needed
            return false
          end,
          additional_vim_regex_highlighting = false,
        },
        indent = {
          enable = true,
        },
      })
      
      -- Suppress treesitter errors from interrupting editing
      vim.treesitter.language.register = (function()
        local register = vim.treesitter.language.register
        return function(lang, filetype)
          local ok, err = pcall(register, lang, filetype)
          if not ok and err then
            -- Silently ignore the error instead of showing it
            return
          end
        end
      end)()
    end,
  },

  -- Jinja2 syntax support
  {
    "Glench/Vim-Jinja2-Syntax",
    ft = { "jinja", "jinja2", "htmljinja" },
  },

  -- Git integration
  {
    'lewis6991/gitsigns.nvim',
    config = function()
      require('gitsigns').setup()
    end,
  },

  -- Auto pairs
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    config = true,
  },

  -- Comment plugin
  {
    'numToStr/Comment.nvim',
    config = true,
  },

  -- Cursor teleport visualization
  {
    'gen740/SmoothCursor.nvim',
    config = function()
      require('smoothcursor').setup({
        type = "default",           -- Cursor movement calculation method, choose "default", "exp" (exponential) or "matrix".
        cursor = "",              -- Cursor shape (need nerd font)
        texthl = "SmoothCursor",   -- Highlight group, default is { bg = None, fg = "#FFD400" }
        linehl = nil,              -- Highlights the line under the cursor, similar to 'cursorline'. "CursorLine" is recommended
        fancy = {
          enable = true,           -- enable fancy mode
          head = { cursor = "▷", texthl = "SmoothCursor", linehl = nil }, -- false to disable fancy head
          body = {
            { cursor = "●", texthl = "SmoothCursorRed" },
            { cursor = "●", texthl = "SmoothCursorOrange" },
            { cursor = "●", texthl = "SmoothCursorYellow" },
            { cursor = "●", texthl = "SmoothCursorGreen" },
            { cursor = "●", texthl = "SmoothCursorAqua" },
            { cursor = "●", texthl = "SmoothCursorBlue" },
            { cursor = "●", texthl = "SmoothCursorPurple" },
          },
          tail = { cursor = nil, texthl = "SmoothCursor" } -- false to disable fancy tail
        },
        matrix = {  -- Loaded when 'type' is set to "matrix"
          head = {
            cursor = require('smoothcursor.matrix_chars'),
            texthl = {
              'SmoothCursor',
            },
            linehl = nil,
          },
          body = {
            length = 6,
            cursor = require('smoothcursor.matrix_chars'),
            texthl = {
              'SmoothCursorGreen',
            },
          },
          tail = {
            cursor = nil,
            texthl = {
              'SmoothCursor',
            },
          },
          unstop = false,
        },
        autostart = true,          -- Automatically start SmoothCursor
        always_redraw = true,      -- Redraw the screen on each update
        flyin_effect = nil,        -- Choose "bottom" or "top" for flying effect
        speed = 25,                -- Max speed is 100 to stick with your terminal's max refresh rate
        intervals = 35,            -- Update intervals in milliseconds
        priority = 10,             -- Set marker priority
        timeout = 3000,            -- Timeout for animations in milliseconds
        threshold = 3,             -- Animate only if cursor moves more than this many lines
        max_threshold = nil,       -- If you move more than this many lines, don't animate (if `nil`, deactivated)
        disable_float_win = false, -- Disable in floating windows
        enabled_filetypes = nil,   -- Enable only for specific file types, e.g., { "lua", "vim" }
        disabled_filetypes = nil,  -- Disable for these file types, ignored if enabled_filetypes is set. e.g., { "TelescopePrompt", "NvimTree" }
      })
    end,
  },

  -- GitHub Copilot
  {
    "github/copilot.vim",
    event = "InsertEnter",
    config = function()
      -- Copilot settings
      vim.g.copilot_no_tab_map = true
      vim.g.copilot_assume_mapped = true
      vim.g.copilot_tab_fallback = ""
      
      -- Enable Copilot for specific filetypes
      vim.g.copilot_filetypes = {
        ["*"] = true,
        ["TelescopePrompt"] = false,
        ["TelescopeResults"] = false,
      }
      
      -- Key mappings for Copilot
      vim.keymap.set("i", "<C-l>", 'copilot#Accept("\\<CR>")', {
        expr = true,
        replace_keycodes = false,
        desc = "Accept Copilot suggestion"
      })
      vim.keymap.set("i", "<C-j>", "<Plug>(copilot-next)", { desc = "Next Copilot suggestion" })
      vim.keymap.set("i", "<C-k>", "<Plug>(copilot-previous)", { desc = "Previous Copilot suggestion" })
      vim.keymap.set("i", "<C-d>", "<Plug>(copilot-dismiss)", { desc = "Dismiss Copilot suggestion" })
      
      -- Add a command to check Copilot status
      vim.api.nvim_create_user_command("CopilotStatus", function()
        vim.cmd("Copilot status")
      end, { desc = "Check Copilot status" })
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
      require("which-key").setup({
        -- Add any specific configuration here if needed
      })
      
      -- Register key groups using new spec format
      require("which-key").add({
        -- File/find group with specific mappings
        { "<leader>f", group = "file/find" },
        { "<leader>ff", desc = "Find files" },
        { "<leader>fg", desc = "Live grep" },
        { "<leader>fb", desc = "Buffers" },
        { "<leader>fh", desc = "Help tags" },
        { "<leader>fc", desc = "Find config" },
        { "<leader>fr", desc = "Recent files" },
        
        -- Code group
        { "<leader>c", group = "code" },
        
        -- Git group
        { "<leader>g", group = "git" },
        
        -- Git hunks group
        { "<leader>h", group = "git hunks" },
        
        -- Rename group
        { "<leader>r", group = "rename" },
        
        -- Workspace group with specific mappings
        { "<leader>w", group = "workspace" },
        { "<leader>wa", desc = "Add workspace folder" },
        { "<leader>wr", desc = "Remove workspace folder" },
        
        -- Individual mappings
        { "<leader>e", desc = "Toggle file tree" },
        { "<leader>ev", desc = "Edit nvim config" },
        { "<leader>u", desc = "Open URL under cursor" },
        { "<leader>z", desc = "Toggle fold" },
        { "<leader>par", desc = "Fix email paragraphs" },
        
        -- LSP mappings to avoid gr conflicts
        { "grr", desc = "References" },
        { "gra", desc = "Code actions" }, 
        { "grn", desc = "Rename" },
        { "gri", desc = "Implementation" },
        { "grt", desc = "Type definition" },
        
        -- Comment mappings to avoid gc/gb conflicts
        { "gc", desc = "Comment toggle linewise" },
        { "gcc", desc = "Comment toggle current line" },
        { "gcO", desc = "Comment insert above" },
        { "gcA", desc = "Comment insert end of line" },
        { "gco", desc = "Comment insert below" },
        { "gb", desc = "Comment toggle blockwise" },
        { "gbc", desc = "Comment toggle current block" },
      })
    end,
  },

  -- LSP Support
  {
    'VonHeikemen/lsp-zero.nvim',
    branch = 'v3.x',
    dependencies = {
      {'williamboman/mason.nvim'},
      {'williamboman/mason-lspconfig.nvim'},
      {'neovim/nvim-lspconfig'},
      {'hrsh7th/nvim-cmp'},
      {'hrsh7th/cmp-nvim-lsp'},
      {'L3MON4D3/LuaSnip'},
    },
    config = function()
      local lsp_zero = require('lsp-zero')
      
      lsp_zero.on_attach(function(client, bufnr)
        lsp_zero.default_keymaps({buffer = bufnr})
      end)

      require('mason').setup({})
      require('mason-lspconfig').setup({
        ensure_installed = {
          'lua_ls',           -- Lua
          'rust_analyzer',    -- Rust
          'pyright',          -- Python
          'ts_ls',            -- TypeScript/JavaScript
          'html',             -- HTML
          'cssls',            -- CSS
          'jsonls',           -- JSON
          'gopls',            -- Go
          'emmet_ls',         -- Emmet for HTML/CSS
        },
        handlers = {
          lsp_zero.default_setup,
          -- Custom handler for HTML to support Jinja2 templates
          html = function()
            require('lspconfig').html.setup({
              filetypes = { 'html', 'templ', 'htmljinja', 'jinja.html' },
              init_options = {
                configurationSection = { "html", "css", "javascript" },
                embeddedLanguages = {
                  css = true,
                  javascript = true
                },
                provideFormatter = true
              }
            })
          end,
        },
      })

      local cmp = require('cmp')
      cmp.setup({
        mapping = cmp.mapping.preset.insert({
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<CR>'] = cmp.mapping.confirm({select = false}),
        })
      })
    end,
  },
}