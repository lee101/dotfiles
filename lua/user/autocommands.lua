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
  pattern = { "*.j2", "*.jinja", "*.jinja2", "*.html.j2", "*.htm.j2" },
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
