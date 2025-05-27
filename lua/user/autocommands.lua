-- ~/.config/nvim/lua/user/autocommands.lua

local group = vim.api.nvim_create_augroup("UserAutocommands", { clear = true })

-- Change to the directory of the file on BufEnter
vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  pattern = "*",
  desc = "Change directory to current file's directory",
  callback = function()
    -- Check if the buffer has a name and is not a temporary/special buffer
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
vim.api.nvim_create_autocmd({ "BufWritePre" }, { -- BufWritePre is better than BufWrite
  group = group,
  pattern = "*",
  desc = "Remove trailing whitespace",
  callback = function()
    if not vim.bo.binary and vim.bo.modifiable and vim.bo.readonly == false then
      local original_cursor_pos = vim.api.nvim_win_get_cursor(0)
      local original_view = vim.fn.winsaveview()
      vim.cmd("silent! %s/\s\+$//e")
      vim.fn.winrestview(original_view)
      -- Only restore cursor if it's still valid, otherwise it might error
      if original_cursor_pos[1] <= vim.api.nvim_buf_line_count(0) then
         vim.api.nvim_win_set_cursor(0, original_cursor_pos)
      end
    end
  end,
})

-- Restore cursor position (Neovim's built-in shada often handles this)
-- If you still want more explicit control, especially for folds:
vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  pattern = "*",
  desc = "Restore cursor position and open folds",
  callback = function()
    -- Check if we should ignore this buffer (e.g., temp buffers)
    if vim.bo.buftype ~= "" or vim.api.nvim_eval('&filetype') == 'gitcommit' then
      return
    end

    local last_known_line = vim.fn.line("'\"")
    if last_known_line > 1 and last_known_line <= vim.fn.line("$") then
      vim.api.nvim_win_set_cursor(0, { last_known_line, vim.fn.col("'\"") - 1 })
      -- Smart fold opening: only if the cursor is on a line that might be folded away
      -- This is a simplified version. The original logic was more complex.
      -- You might want to just use `normal! zv` if your folds are simple markers
      -- or rely on Neovim's view/session features (see :h viewoptions, :h mksession)
      -- if foldlevel(last_known_line) > 0 then
      --   vim.cmd("normal! zv")
      -- end
    end
  end,
}) 