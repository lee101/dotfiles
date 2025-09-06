-- Smart line/block movement similar to IntelliJ
-- Moves entire code blocks semantically when possible

local M = {}

-- Function to get the current treesitter node
local function get_current_node()
  local ts_utils = require('nvim-treesitter.ts_utils')
  return ts_utils.get_node_at_cursor()
end

-- Smart move up function
function M.smart_move_up()
  local node = get_current_node()
  
  if not node then
    -- Fallback to regular line movement
    vim.cmd('normal! ddkP')
    return
  end
  
  local parent = node:parent()
  if parent and parent:type():match("block") then
    -- Try to move the entire statement/block
    local start_row, _, end_row, _ = node:range()
    if start_row > 0 then
      vim.cmd(string.format('%d,%dmove %d', start_row + 1, end_row + 1, start_row - 1))
      vim.cmd('normal! ==')
    end
  else
    -- Regular line movement with auto-indent
    vim.cmd('move .-2')
    vim.cmd('normal! ==')
  end
end

-- Smart move down function
function M.smart_move_down()
  local node = get_current_node()
  
  if not node then
    -- Fallback to regular line movement
    vim.cmd('normal! ddp')
    return
  end
  
  local parent = node:parent()
  if parent and parent:type():match("block") then
    -- Try to move the entire statement/block
    local start_row, _, end_row, _ = node:range()
    local total_lines = vim.api.nvim_buf_line_count(0)
    if end_row < total_lines - 1 then
      vim.cmd(string.format('%d,%dmove %d', start_row + 1, end_row + 1, end_row + 2))
      vim.cmd('normal! ==')
    end
  else
    -- Regular line movement with auto-indent
    vim.cmd('move .+1')
    vim.cmd('normal! ==')
  end
end

-- Smart move for visual selection
function M.smart_move_visual_up()
  vim.cmd("'<,'>move '<-2")
  vim.cmd('normal! gv=gv')
end

function M.smart_move_visual_down()
  vim.cmd("'<,'>move '>+1")
  vim.cmd('normal! gv=gv')
end

return M