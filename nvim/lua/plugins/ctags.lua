-- Automatic ctags generation for Go and other languages
return {
  -- vim-gutentags for automatic tags management
  {
    "ludovicchabant/vim-gutentags",
    config = function()
      -- Disable gutentags by default (was causing hanging)
      -- Re-enable with :let g:gutentags_enabled = 1
      vim.g.gutentags_enabled = 0
      
      -- Define ctags executable (uses universal-ctags if available, falls back to ctags)
      vim.g.gutentags_ctags_executable = 'ctags'
      
      -- Project root markers (gutentags will look for these to determine project root)
      vim.g.gutentags_project_root = {'.git', '.hg', '.svn', 'go.mod', 'package.json', 'Cargo.toml'}
      
      -- Where to store tag files
      vim.g.gutentags_cache_dir = vim.fn.expand('~/.cache/nvim/ctags/')
      
      -- Exclude patterns
      vim.g.gutentags_ctags_exclude = {
        '*.git', '*.svg', '*.hg',
        '*/tests/*',
        'build',
        'dist',
        '*sites/*/files/*',
        'bin',
        'node_modules',
        'bower_components',
        'cache',
        'compiled',
        'docs',
        'example',
        'bundle',
        'vendor',
        '*.md',
        '*-lock.json',
        '*.lock',
        '*bundle*.js',
        '*build*.js',
        '.*rc*',
        '*.json',
        '*.min.*',
        '*.map',
        '*.bak',
        '*.zip',
        '*.pyc',
        '*.class',
        '*.sln',
        '*.Master',
        '*.csproj',
        '*.tmp',
        '*.csproj.user',
        '*.cache',
        '*.pdb',
        'tags*',
        'cscope.*',
        '*.css',
        '*.less',
        '*.scss',
        '*.exe', '*.dll',
        '*.mp3', '*.ogg', '*.flac',
        '*.swp', '*.swo',
        '*.bmp', '*.gif', '*.ico', '*.jpg', '*.png',
        '*.rar', '*.zip', '*.tar', '*.tar.gz', '*.tar.xz', '*.tar.bz2',
        '*.pdf', '*.doc', '*.docx', '*.ppt', '*.pptx',
      }
      
      -- Extra args for ctags
      vim.g.gutentags_ctags_extra_args = {
        '--tag-relative=yes',
        '--fields=+ailmnS',
        '--extras=+q',
        '--kinds-go=+p',  -- Include Go package names
        '--kinds-go=+f',  -- Include Go functions
        '--kinds-go=+v',  -- Include Go variables
        '--kinds-go=+t',  -- Include Go types
        '--kinds-go=+c',  -- Include Go constants
      }
      
      -- Add support for Go modules
      vim.g.gutentags_file_list_command = {
        markers = {
          ['go.mod'] = 'find . -type f -name "*.go" -not -path "./vendor/*"',
        },
      }
      
      -- Only generate tags for files tracked by git (if in a git repo)
      vim.g.gutentags_generate_on_new = 1
      vim.g.gutentags_generate_on_missing = 1
      vim.g.gutentags_generate_on_write = 1
      vim.g.gutentags_generate_on_empty_buffer = 0
      
      -- Create cache directory if it doesn't exist
      vim.fn.system('mkdir -p ' .. vim.fn.expand('~/.cache/nvim/ctags/'))
    end,
  },
  
  -- Telescope extension for tags
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      -- Add keymaps for tag navigation using Telescope
      local builtin = require('telescope.builtin')
      
      -- Search tags in current buffer
      vim.keymap.set('n', '<leader>ft', builtin.current_buffer_tags, { desc = "Find tags in current buffer" })
      
      -- Search all tags in project
      vim.keymap.set('n', '<leader>fT', builtin.tags, { desc = "Find all tags in project" })
      
      -- Jump to definition under cursor (using tags)
      vim.keymap.set('n', '<C-]>', function()
        -- Try LSP first, fall back to tags
        local params = vim.lsp.util.make_position_params()
        vim.lsp.buf_request(0, 'textDocument/definition', params, function(err, result, ctx, config)
          if err or not result or vim.tbl_isempty(result) then
            -- LSP failed, use tags
            vim.cmd('tag ' .. vim.fn.expand('<cword>'))
          else
            -- LSP succeeded
            vim.lsp.buf.definition()
          end
        end)
      end, { desc = "Go to definition (LSP/tags)" })
      
      -- Alternative keybinding for go to definition
      vim.keymap.set('n', 'gd', '<C-]>', { desc = "Go to definition", remap = true })
      
      -- Go back from tag jump
      vim.keymap.set('n', '<C-t>', '<C-t>', { desc = "Go back from tag jump" })
    end,
  },
}