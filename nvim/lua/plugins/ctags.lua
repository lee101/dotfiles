-- Automatic ctags generation for Go and other languages
return {
  -- vim-gutentags for automatic tags management
  {
    "ludovicchabant/vim-gutentags",
    config = function()
      -- Disable gutentags by default (enable manually for specific projects)
      -- Re-enable with :GutentagsToggleEnabled or :let g:gutentags_enabled = 1
      vim.g.gutentags_enabled = 0
      
      -- Define ctags executable (uses universal-ctags if available, falls back to ctags)
      vim.g.gutentags_ctags_executable = 'ctags'
      
      -- Project root markers (gutentags will look for these to determine project root)
      vim.g.gutentags_project_root = {'.git', '.hg', '.svn', 'go.mod', 'package.json', 'Cargo.toml', 'pyproject.toml', 'setup.py', 'Gemfile', 'pom.xml', 'build.gradle'}
      
      -- Where to store tag files
      vim.g.gutentags_cache_dir = vim.fn.expand('~/.cache/nvim/ctags/')
      
      -- Integrate with .gitignore - respect git's ignore rules
      vim.g.gutentags_ctags_exclude_wildignore = 1
      vim.g.gutentags_ctags_extra_args = {'--exclude=@.gitignore'}
      
      -- Comprehensive exclude patterns for multiple languages
      vim.g.gutentags_ctags_exclude = {
        -- Version control
        '*.git', '*.hg', '*.svn', '.git/*', '.hg/*', '.svn/*',
        
        -- Build artifacts and dependencies
        'node_modules', 'bower_components', 'vendor', 'vendors',
        'target', 'build', 'dist', 'out', 'output', 'bin', 'obj',
        '.gradle', '.mvn', '.idea', '.vscode', '.vs',
        '__pycache__', '*.egg-info', '.pytest_cache', '.tox',
        '.bundle', '.sass-cache', 'coverage', '.nyc_output',
        '.next', '.nuxt', '.cache', 'tmp', 'temp',
        
        -- Package management
        '*.lock', 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml',
        'Gemfile.lock', 'poetry.lock', 'Pipfile.lock', 'composer.lock',
        
        -- Compiled/Minified files
        '*.min.js', '*.min.css', '*.bundle.js', '*.bundle.css',
        '*-min.js', '*-min.css', '*.compiled.js', '*.compiled.css',
        '*.production.js', 'dist.js', 'bundle.js',
        
        -- Source maps
        '*.map', '*.js.map', '*.css.map',
        
        -- Documentation
        'docs', 'doc', 'documentation', 'api-docs', 'javadoc',
        '*.md', '*.rst', '*.txt', 'README*', 'LICENSE*', 'CHANGELOG*',
        
        -- Test directories
        'test', 'tests', 'spec', 'specs', '__tests__', 'test_*',
        '*_test.go', '*_test.py', '*.test.js', '*.spec.js',
        'cypress', 'e2e', 'integration', 'fixtures',
        
        -- Examples and demos
        'example', 'examples', 'demo', 'demos', 'sample', 'samples',
        
        -- Python specific
        '*.pyc', '*.pyo', '*.pyd', '.Python', '*.so',
        'pip-log.txt', 'pip-delete-this-directory.txt',
        '.ipynb_checkpoints', '*.ipynb', '.mypy_cache', '.dmypy.json',
        'htmlcov', '.coverage', '.hypothesis', 'celerybeat-schedule',
        
        -- JavaScript/TypeScript specific  
        '*.tsbuildinfo', '.eslintcache', '.parcel-cache',
        'bower_components', '.grunt', '.npm', '.yarn',
        '*.chunk.js', 'webpack.config.js', 'rollup.config.js',
        
        -- Java/JVM specific
        '*.class', '*.jar', '*.war', '*.ear', '*.iml',
        '.settings', '.classpath', '.project', '.factorypath',
        
        -- C/C++ specific
        '*.o', '*.obj', '*.exe', '*.dll', '*.so', '*.dylib',
        '*.a', '*.lib', '*.pch', '*.gch', '.ccls-cache',
        
        -- Go specific
        '*.test', '*.out', 'go.sum',
        
        -- Ruby specific
        '*.gem', '*.rbc', '.rspec', '.rvmrc', '.rbenv-version',
        '.yardoc', '_yardoc', 'rdoc',
        
        -- Rust specific
        'Cargo.lock', 'target',
        
        -- IDE/Editor files
        '*.swp', '*.swo', '*~', '.#*', '#*#',
        '.idea', '.vscode', '*.sublime-*', '.atom',
        '.DS_Store', 'Thumbs.db', 'desktop.ini',
        
        -- Archives
        '*.zip', '*.tar', '*.tar.gz', '*.tar.xz', '*.tar.bz2',
        '*.rar', '*.7z', '*.dmg', '*.iso',
        
        -- Media files
        '*.jpg', '*.jpeg', '*.png', '*.gif', '*.bmp', '*.svg', '*.ico',
        '*.webp', '*.mp3', '*.mp4', '*.avi', '*.mov', '*.wmv',
        '*.flac', '*.wav', '*.ogg', '*.webm',
        
        -- Fonts
        '*.ttf', '*.otf', '*.woff', '*.woff2', '*.eot',
        
        -- Office documents
        '*.pdf', '*.doc', '*.docx', '*.xls', '*.xlsx',
        '*.ppt', '*.pptx', '*.odt', '*.ods', '*.odp',
        
        -- Database files
        '*.db', '*.sqlite', '*.sqlite3', '*.mdb',
        
        -- Log files
        '*.log', 'logs', 'log',
        
        -- Environment files
        '.env', '.env.*', '*.env',
        
        -- Large/Generated files
        'package.json', 'composer.json', '*.generated.*',
        '*.auto.*', 'TAGS', 'tags', 'GTAGS', 'GRTAGS', 'GPATH',
        'cscope.*',
        
        -- CSS preprocessors
        '*.sass', '*.scss', '*.less', '*.styl',
        
        -- Config files (usually not needed for navigation)
        '.*rc', '.*rc.js', '.*rc.json', '.*rc.yml', '.*rc.yaml',
        '*.config.js', '*.config.json', 'tsconfig.json', 'jsconfig.json',
      }
      
      -- Extra args for ctags with performance optimizations
      vim.g.gutentags_ctags_extra_args = {
        '--tag-relative=yes',
        '--fields=+ailmnS',
        '--extras=+q',
        '--sort=yes',  -- Sort tags for better performance
        '--append=no', -- Don't append, regenerate
        
        -- Language-specific settings
        '--kinds-go=+p+f+v+t+c',     -- Go: packages, functions, variables, types, constants
        '--kinds-python=+cfmvi',      -- Python: classes, functions, methods, variables, imports
        '--kinds-javascript=+cfmvp',  -- JS: classes, functions, methods, variables, properties
        '--kinds-typescript=+cfmvipe', -- TS: classes, functions, methods, variables, interfaces, properties, enums
        '--kinds-rust=+fsmtgMei',     -- Rust: functions, structs, modules, traits, enums, etc
        '--kinds-c++=+pcfgnsutm',     -- C++: comprehensive kinds
        '--kinds-java=+pcifgm',       -- Java: packages, classes, interfaces, fields, methods
        '--kinds-ruby=+cfmF',         -- Ruby: classes, methods, functions, singleton methods
      }
      
      -- Use git ls-files when in git repository for better performance
      vim.g.gutentags_file_list_command = {
        markers = {
          ['.git'] = 'git ls-files',
          ['go.mod'] = 'find . -type f -name "*.go" -not -path "./vendor/*" | head -5000',
          ['package.json'] = 'find . -type f \\( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" \\) -not -path "./node_modules/*" | head -5000',
          ['Cargo.toml'] = 'find . -type f -name "*.rs" -not -path "./target/*" | head -5000',
        },
      }
      
      -- Performance settings
      vim.g.gutentags_generate_on_new = 0      -- Don't generate on new files
      vim.g.gutentags_generate_on_missing = 1  -- Generate if tags file missing
      vim.g.gutentags_generate_on_write = 0    -- Don't regenerate on every write
      vim.g.gutentags_generate_on_empty_buffer = 0
      
      -- Limit tag generation to reasonable project sizes
      vim.g.gutentags_exclude_filetypes = {
        'gitcommit', 'gitconfig', 'gitrebase', 'gitsendemail',
        'git', 'diff', 'fugitive', 'help', 'markdown',
        'text', 'yaml', 'json', 'xml', 'html', 'css',
      }
      
      -- Status line indicator
      vim.g.gutentags_status_line = '[Ctags]'
      vim.g.gutentags_status_line_done = '[Ctags OK]'
      
      -- Create cache directory if it doesn't exist
      vim.fn.system('mkdir -p ' .. vim.fn.expand('~/.cache/nvim/ctags/'))
      
      -- Helper commands for manual control
      vim.cmd([[
        command! GutentagsToggleEnabled let g:gutentags_enabled = !g:gutentags_enabled | echo "Gutentags: " . (g:gutentags_enabled ? "Enabled" : "Disabled")
        command! GutentagsUpdate :GutentagsUpdate!
        command! GutentagsClear :!rm -f ~/.cache/nvim/ctags/*
      ]])
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