-- Smart Git-based auto-reload with automatic merge of changes
local M = {}

-- Cache for tracking file states
M.file_states = {}
M.merge_in_progress = {}

-- Helper function to get git base content of a file
local function get_git_base_content(filepath)
  local handle = io.popen('git show HEAD:"' .. vim.fn.fnamemodify(filepath, ':~:.') .. '" 2>/dev/null')
  if handle then
    local content = handle:read("*a")
    handle:close()
    if content and content ~= "" then
      return vim.split(content, '\n')
    end
  end
  return nil
end

-- Helper function to check if we're in a git repo
local function is_git_repo()
  local handle = io.popen('git rev-parse --is-inside-work-tree 2>/dev/null')
  if handle then
    local result = handle:read("*a")
    handle:close()
    return result:match("true") ~= nil
  end
  return false
end

-- Get current buffer content as lines
local function get_buffer_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
end

-- Get file content from disk
local function get_file_lines(filepath)
  local file = io.open(filepath, "r")
  if not file then return nil end
  local content = file:read("*a")
  file:close()
  return vim.split(content, '\n')
end

-- Smart three-way merge of changes
local function smart_merge(base_lines, local_lines, remote_lines)
  if not base_lines then
    -- No base, just try to merge local and remote intelligently
    return merge_without_base(local_lines, remote_lines)
  end
  
  local merged = {}
  local max_lines = math.max(#base_lines, #local_lines, #remote_lines)
  
  for i = 1, max_lines do
    local base = base_lines[i] or ""
    local local_line = local_lines[i] or ""
    local remote = remote_lines[i] or ""
    
    if local_line == remote then
      -- Both same, use it
      table.insert(merged, local_line)
    elseif local_line == base then
      -- Only remote changed, take remote
      table.insert(merged, remote)
    elseif remote == base then
      -- Only local changed, take local
      table.insert(merged, local_line)
    else
      -- Both changed differently - accept both changes
      -- This is the smart part - we keep both versions
      if local_line ~= "" and remote ~= "" and local_line ~= remote then
        -- Add both with markers
        table.insert(merged, "<<<<<<< LOCAL")
        table.insert(merged, local_line)
        table.insert(merged, "=======")
        table.insert(merged, remote)
        table.insert(merged, ">>>>>>> REMOTE")
      elseif local_line ~= "" then
        table.insert(merged, local_line)
      else
        table.insert(merged, remote)
      end
    end
  end
  
  return merged
end

-- Merge without base (two-way merge)
local function merge_without_base(local_lines, remote_lines)
  local merged = {}
  local max_lines = math.max(#local_lines, #remote_lines)
  
  -- Simple heuristic: if lines are different, keep both
  for i = 1, max_lines do
    local local_line = local_lines[i] or ""
    local remote_line = remote_lines[i] or ""
    
    if local_line == remote_line then
      table.insert(merged, local_line)
    elseif local_line == "" then
      table.insert(merged, remote_line)
    elseif remote_line == "" then
      table.insert(merged, local_line)
    else
      -- Keep both different lines
      table.insert(merged, "<<<<<<< LOCAL")
      table.insert(merged, local_line)
      table.insert(merged, "=======")
      table.insert(merged, remote_line)
      table.insert(merged, ">>>>>>> REMOTE")
    end
  end
  
  return merged
end

-- Auto-resolve conflict markers if possible
local function auto_resolve_conflicts(lines)
  local resolved = {}
  local in_conflict = false
  local local_content = {}
  local remote_content = {}
  local in_local = false
  
  for _, line in ipairs(lines) do
    if line:match("^<<<<<<< LOCAL") then
      in_conflict = true
      in_local = true
      local_content = {}
      remote_content = {}
    elseif line:match("^=======") and in_conflict then
      in_local = false
    elseif line:match("^>>>>>>> REMOTE") and in_conflict then
      -- Try to auto-resolve
      -- Strategy: Keep both if they're meaningful different additions
      -- Otherwise keep the one with more content
      in_conflict = false
      
      local local_str = table.concat(local_content, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
      local remote_str = table.concat(remote_content, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
      
      if local_str == remote_str then
        -- Same content, just keep one
        vim.list_extend(resolved, local_content)
      elseif local_str == "" then
        -- Local is empty, keep remote
        vim.list_extend(resolved, remote_content)
      elseif remote_str == "" then
        -- Remote is empty, keep local
        vim.list_extend(resolved, local_content)
      else
        -- Both have different content, keep both without conflict markers
        -- This is the "accept both changes" behavior
        vim.list_extend(resolved, local_content)
        vim.list_extend(resolved, remote_content)
      end
      
      local_content = {}
      remote_content = {}
    elseif in_conflict then
      if in_local then
        table.insert(local_content, line)
      else
        table.insert(remote_content, line)
      end
    else
      table.insert(resolved, line)
    end
  end
  
  return resolved
end

-- Main reload function with smart merging
function M.smart_reload(bufnr, filepath)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  filepath = filepath or vim.api.nvim_buf_get_name(bufnr)
  
  if filepath == "" or M.merge_in_progress[filepath] then
    return
  end
  
  M.merge_in_progress[filepath] = true
  
  -- Get the three versions
  local local_lines = get_buffer_lines(bufnr)
  local remote_lines = get_file_lines(filepath)
  
  if not remote_lines then
    M.merge_in_progress[filepath] = false
    return
  end
  
  -- Check if buffer has been modified
  local modified = vim.bo[bufnr].modified
  
  if not modified then
    -- No local changes, just reload
    vim.cmd('edit!')
    vim.notify("File reloaded (no local changes)", vim.log.levels.INFO)
    M.merge_in_progress[filepath] = false
    return
  end
  
  -- We have local changes, do smart merge
  local base_lines = nil
  if is_git_repo() then
    base_lines = get_git_base_content(filepath)
  end
  
  -- Perform three-way merge
  local merged_lines = smart_merge(base_lines, local_lines, remote_lines)
  
  -- Auto-resolve conflicts where possible
  merged_lines = auto_resolve_conflicts(merged_lines)
  
  -- Save cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  
  -- Apply merged content
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, merged_lines)
  
  -- Try to restore cursor position
  pcall(vim.api.nvim_win_set_cursor, 0, cursor)
  
  -- Check if we have any remaining conflicts
  local has_conflicts = false
  for _, line in ipairs(merged_lines) do
    if line:match("^<<<<<<<") or line:match("^>>>>>>>") then
      has_conflicts = true
      break
    end
  end
  
  if has_conflicts then
    vim.notify("File reloaded with conflicts merged (review markers)", vim.log.levels.WARN)
  else
    vim.notify("File reloaded and changes merged automatically", vim.log.levels.INFO)
  end
  
  -- Mark buffer as modified since we merged changes
  vim.bo[bufnr].modified = true
  
  M.merge_in_progress[filepath] = false
end

-- Setup autocmds for smart reloading
function M.setup()
  local group = vim.api.nvim_create_augroup('SmartReload', { clear = true })
  
  -- Check for changes on various events
  vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold' }, {
    group = group,
    pattern = '*',
    callback = function()
      if vim.fn.mode() ~= 'c' and vim.fn.getcmdwintype() == '' then
        vim.cmd('checktime')
      end
    end,
  })
  
  -- Handle file changes with smart merging
  vim.api.nvim_create_autocmd('FileChangedShell', {
    group = group,
    pattern = '*',
    callback = function(args)
      local bufnr = args.buf
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      
      -- Automatically do smart reload
      M.smart_reload(bufnr, filepath)
      
      -- Prevent the default behavior
      vim.v.fcs_choice = 'reload'
    end,
  })
  
  -- Command to manually trigger smart reload
  vim.api.nvim_create_user_command('SmartReload', function()
    M.smart_reload()
  end, { desc = 'Manually trigger smart reload with merge' })
  
  -- Command to show merge status
  vim.api.nvim_create_user_command('MergeStatus', function()
    local filepath = vim.api.nvim_buf_get_name(0)
    local has_conflicts = false
    local lines = get_buffer_lines()
    
    for _, line in ipairs(lines) do
      if line:match("^<<<<<<<") or line:match("^>>>>>>>") then
        has_conflicts = true
        break
      end
    end
    
    if has_conflicts then
      print("Buffer has unresolved merge conflicts")
    else
      print("No merge conflicts in buffer")
    end
  end, { desc = 'Check for merge conflicts in current buffer' })
end

return M