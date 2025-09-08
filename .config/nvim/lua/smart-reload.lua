-- Smart file reload with git-style conflict resolution
local M = {}

local function get_buffer_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_buffer_lines(bufnr, lines)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

-- Simple 3-way merge algorithm
local function three_way_merge(original, current, external)
  local result = {}
  local max_lines = math.max(#original, #current, #external)
  
  for i = 1, max_lines do
    local orig_line = original[i] or ""
    local curr_line = current[i] or ""
    local ext_line = external[i] or ""
    
    if curr_line == orig_line then
      -- No local changes, accept external
      table.insert(result, ext_line)
    elseif ext_line == orig_line then
      -- No external changes, keep local
      table.insert(result, curr_line)
    elseif curr_line == ext_line then
      -- Both changed to same thing
      table.insert(result, curr_line)
    else
      -- Both changed differently - try to merge
      -- For now, append both (like git's "accept both changes")
      if curr_line ~= "" and ext_line ~= "" and curr_line ~= ext_line then
        -- Add marker comments if both have content
        table.insert(result, "<<<<<<< LOCAL")
        table.insert(result, curr_line)
        table.insert(result, "=======")
        table.insert(result, ext_line)
        table.insert(result, ">>>>>>> EXTERNAL")
      elseif curr_line ~= "" then
        table.insert(result, curr_line)
      else
        table.insert(result, ext_line)
      end
    end
  end
  
  return result
end

-- Smart merge without conflict markers when possible
local function smart_merge(original, current, external)
  local result = {}
  local i = 1
  local j = 1
  local k = 1
  
  -- Track sections that have been processed
  local processed = {}
  
  -- First pass: identify unchanged sections
  while i <= #current and j <= #external do
    if current[i] == external[j] then
      -- Lines match, keep them
      table.insert(result, current[i])
      i = i + 1
      j = j + 1
    else
      -- Find next matching section
      local found = false
      
      -- Look ahead for matching lines
      for di = 0, math.min(10, #current - i) do
        for dj = 0, math.min(10, #external - j) do
          if current[i + di] == external[j + dj] then
            -- Found matching section
            -- Add current lines up to match
            for ci = i, i + di - 1 do
              if current[ci] ~= "" then
                table.insert(result, current[ci])
              end
            end
            -- Add external lines up to match
            for ej = j, j + dj - 1 do
              if external[ej] ~= "" and external[ej] ~= current[i + di - 1] then
                table.insert(result, external[ej])
              end
            end
            i = i + di
            j = j + dj
            found = true
            break
          end
        end
        if found then break end
      end
      
      if not found then
        -- No match found, include both versions
        if current[i] ~= "" then
          table.insert(result, current[i])
        end
        if j <= #external and external[j] ~= "" and external[j] ~= current[i] then
          table.insert(result, external[j])
        end
        i = i + 1
        j = j + 1
      end
    end
  end
  
  -- Add remaining lines
  while i <= #current do
    table.insert(result, current[i])
    i = i + 1
  end
  
  while j <= #external do
    table.insert(result, external[j])
    j = j + 1
  end
  
  return result
end

function M.setup()
  -- Store original content when buffer is loaded
  local original_content = {}
  
  vim.api.nvim_create_augroup('SmartReload', { clear = true })
  
  -- Store original content when buffer is first loaded
  vim.api.nvim_create_autocmd('BufReadPost', {
    group = 'SmartReload',
    pattern = '*',
    callback = function(args)
      local bufnr = args.buf
      original_content[bufnr] = get_buffer_lines(bufnr)
    end,
  })
  
  -- Check for changes periodically
  vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'CursorHoldI' }, {
    group = 'SmartReload',
    pattern = '*',
    callback = function()
      if vim.fn.mode() ~= 'c' and vim.fn.getcmdwintype() == '' then
        vim.cmd('checktime')
      end
    end,
  })
  
  -- Handle file changes with smart merging
  vim.api.nvim_create_autocmd('FileChangedShell', {
    group = 'SmartReload',
    pattern = '*',
    callback = function(args)
      local bufnr = args.buf
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      local modified = vim.bo[bufnr].modified
      
      if not modified then
        -- No local changes, just reload
        vim.v.fcs_choice = 'reload'
        -- Update original content
        vim.schedule(function()
          original_content[bufnr] = get_buffer_lines(bufnr)
        end)
      else
        -- Has local changes, try smart merge
        local current_lines = get_buffer_lines(bufnr)
        
        -- Read external file content
        local external_lines = {}
        local file = io.open(filepath, "r")
        if file then
          for line in file:lines() do
            table.insert(external_lines, line)
          end
          file:close()
        end
        
        -- Get original content (or use current as fallback)
        local orig_lines = original_content[bufnr] or current_lines
        
        -- Attempt smart merge
        local merged = smart_merge(orig_lines, current_lines, external_lines)
        
        -- Apply merged content
        vim.schedule(function()
          -- Save cursor position
          local cursor = vim.api.nvim_win_get_cursor(0)
          
          -- Update buffer with merged content
          set_buffer_lines(bufnr, merged)
          
          -- Mark as modified since we merged changes
          vim.bo[bufnr].modified = true
          
          -- Restore cursor position (adjust if needed)
          local new_line_count = vim.api.nvim_buf_line_count(bufnr)
          if cursor[1] > new_line_count then
            cursor[1] = new_line_count
          end
          vim.api.nvim_win_set_cursor(0, cursor)
          
          -- Update original content to current external
          original_content[bufnr] = external_lines
          
          -- Notify user
          vim.notify('File changed externally - merged changes automatically', vim.log.levels.INFO)
        end)
        
        -- Tell Vim we handled it
        vim.v.fcs_choice = 'keep'
      end
    end,
  })
  
  -- Clean up when buffer is deleted
  vim.api.nvim_create_autocmd('BufDelete', {
    group = 'SmartReload',
    pattern = '*',
    callback = function(args)
      original_content[args.buf] = nil
    end,
  })
end

return M