-- ~/.config/nvim/lua/user/autocommands.lua

-- Create augroup using older API
vim.cmd [[
  augroup UserAutocommands
    autocmd!
  augroup END
]]

-- Change to the directory of the file on BufEnter
vim.cmd [[
  autocmd UserAutocommands BufEnter * lua <<EOF
    local bufname = vim.fn.bufname("%")
    if bufname ~= "" and vim.fn.filereadable(bufname) == 1 then
      local dir = vim.fn.expand("%:p:h")
      if dir ~= "" and dir ~= vim.fn.getcwd() then
        vim.cmd("silent! chdir " .. vim.fn.escape(dir, " "))
      end
    end
EOF
]]

-- Remove trailing whitespace on save
vim.cmd [[
  autocmd UserAutocommands BufWritePre * lua <<EOF
    if not vim.bo.binary and vim.bo.modifiable and vim.bo.readonly == false then
      local original_cursor_pos = vim.api.nvim_win_get_cursor(0)
      local original_view = vim.fn.winsaveview()
      vim.cmd("silent! %s/\\s\\+$//e")
      vim.fn.winrestview(original_view)
      if original_cursor_pos[1] <= vim.api.nvim_buf_line_count(0) then
         vim.api.nvim_win_set_cursor(0, original_cursor_pos)
      end
    end
EOF
]]

-- Restore cursor position
vim.cmd [[
  autocmd UserAutocommands BufReadPost * lua <<EOF
    if vim.bo.buftype ~= "" or vim.api.nvim_eval('&filetype') == 'gitcommit' then
      return
    end
    
    local last_known_line = vim.fn.line("'\"")
    if last_known_line > 1 and last_known_line <= vim.fn.line("$") then
      vim.api.nvim_win_set_cursor(0, { last_known_line, vim.fn.col("'\"") - 1 })
    end
EOF
]] 