-- ~/.config/nvim/lua/user/autocommands.lua

-- Create augroup for all autocommands
local group = vim.api.nvim_create_augroup("UserAutocommands", { clear = true })

-- Change to the directory of the file on BufEnter
vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  desc = "Change to directory of file",
  callback = function()
    local bufname = vim.fn.bufname("%")
    if bufname ~= "" and vim.fn.filereadable(bufname) == 1 then
      local dir = vim.fn.expand("%:p:h")
      if dir ~= "" and dir ~= vim.fn.getcwd() then
        vim.cmd("silent! chdir " .. vim.fn.escape(dir, " "))
      end
    end
  end,
})

-- Remove trailing whitespace on save
vim.api.nvim_create_autocmd("BufWritePre", {
  group = group,
  desc = "Remove trailing whitespace",
  callback = function()
    if not vim.bo.binary and vim.bo.modifiable and vim.bo.readonly == false then
      local original_cursor_pos = vim.api.nvim_win_get_cursor(0)
      local original_view = vim.fn.winsaveview()
      vim.cmd("silent! %s/\\s\\+$//e")
      vim.fn.winrestview(original_view)
      if original_cursor_pos[1] <= vim.api.nvim_buf_line_count(0) then
         vim.api.nvim_win_set_cursor(0, original_cursor_pos)
      end
    end
  end,
})

-- Restore cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  desc = "Restore cursor position",
  callback = function()
    if vim.bo.buftype ~= "" or vim.api.nvim_eval('&filetype') == 'gitcommit' then
      return
    end
    
    local last_known_line = vim.fn.line("'\"")
    if last_known_line > 1 and last_known_line <= vim.fn.line("$") then
      vim.api.nvim_win_set_cursor(0, { last_known_line, vim.fn.col("'\"") - 1 })
    end
  end,
})

-- Jinja2 file type associations
vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  group = group,
  pattern = { "*.j2", "*.jinja", "*.jinja2", "*.html.j2", "*.htm.j2", "*.pongo" },
  desc = "Set filetype for Jinja2 templates",
  callback = function()
    vim.bo.filetype = "htmljinja"
  end,
})

-- Additional template file associations
vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  group = group,
  pattern = { "*.template", "*.tmpl" },
  desc = "Set filetype for generic templates",
  callback = function()
    local ext = vim.fn.expand("%:e:e") -- Get second extension if exists
    if ext == "html" or ext == "htm" then
      vim.bo.filetype = "htmljinja"
    else
      vim.bo.filetype = "jinja"
    end
  end,
})

-- Suppress treesitter decoration errors
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "TSError",
  desc = "Suppress treesitter errors",
  callback = function()
    -- Just return to suppress the error
    return true
  end,
})

-- Override vim.notify for treesitter errors
local original_notify = vim.notify
vim.notify = function(msg, level, opts)
  -- Filter out treesitter highlighter errors
  if type(msg) == "string" and (
    msg:match("Error in decoration provider") or
    msg:match("treesitter/highlighter") or
    msg:match("Invalid 'end_col'") or
    msg:match("out of range")
  ) then
    -- Silently ignore treesitter highlighting errors
    return
  end
  -- Pass through all other notifications
  return original_notify(msg, level, opts)
end

-- Configure tags for Go and other languages
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "go", "python", "javascript", "typescript", "rust", "c", "cpp" },
  desc = "Configure tags for programming languages",
  callback = function()
    -- Look for tags in the central cache directory
    local cache_dir = vim.fn.expand("~/.cache/nvim/ctags/")
    
    -- Try to find project root
    local markers = {'.git', 'go.mod', 'package.json', 'Cargo.toml', 'pyproject.toml', 'setup.py', 'Gemfile', 'pom.xml', 'build.gradle'}
    local project_root = nil
    
    for _, marker in ipairs(markers) do
      local found = vim.fn.findfile(marker, ".;")
      if found == "" then
        found = vim.fn.finddir(marker, ".;")
      end
      if found ~= "" then
        project_root = vim.fn.fnamemodify(found, ":h")
        break
      end
    end
    
    if project_root then
      local project_name = vim.fn.fnamemodify(project_root, ":t")
      -- Look for cached tags file
      local possible_tag_files = vim.fn.glob(cache_dir .. project_name .. "-*.tags", false, true)
      
      if #possible_tag_files > 0 then
        -- Use the first matching tag file
        vim.opt_local.tags = possible_tag_files[1]
      else
        -- Fallback to standard locations (shouldn't be in project dir anymore)
        vim.opt_local.tags = cache_dir .. "*.tags"
      end
    end
    
    -- For Go specifically, add GOPATH tags if available
    if vim.bo.filetype == "go" then
      local gopath = vim.fn.system("go env GOPATH"):gsub("\n", "")
      if gopath ~= "" then
        vim.opt_local.tags:append(cache_dir .. "gopath.tags")
      end
    end
  end,
})

-- Auto-generate tags on save for Go files (backup in case gutentags fails)
vim.api.nvim_create_autocmd("BufWritePost", {
  group = group,
  pattern = "*.go",
  desc = "Generate tags for Go files on save",
  callback = function()
    -- Only run if gutentags is not working
    if not vim.g.gutentags_enabled or vim.fn.exists('*gutentags#statusline') == 0 then
      -- Find project root (go.mod)
      local root = vim.fn.findfile("go.mod", ".;")
      if root ~= "" then
        local project_dir = vim.fn.fnamemodify(root, ":h")
        local project_name = vim.fn.fnamemodify(project_dir, ":t")
        local cache_dir = vim.fn.expand("~/.cache/nvim/ctags/")
        
        -- Create cache directory if it doesn't exist
        vim.fn.system("mkdir -p " .. cache_dir)
        
        -- Generate unique tag filename based on project path
        local tag_file = cache_dir .. project_name .. "-" .. vim.fn.sha256(project_dir) .. ".tags"
        
        -- Run ctags asynchronously to central cache
        vim.fn.jobstart(
          string.format(
            'ctags -R --languages=go --Go-kinds=+p+f+v+t+c --extras=+q -f %s %s',
            tag_file,
            project_dir
          ),
          { detach = true }
        )
        
        -- Set the tags option to use the cached file
        vim.opt_local.tags = tag_file
      end
    end
  end,
})
