-- ~/.config/nvim/lua/user/commands.lua

-- Write file with sudo
vim.api.nvim_create_user_command('W',
  function(opts)
    -- Check if there are any arguments to W, if so, treat it as :w new_file_sudo
    if opts.fargs[1] then
        vim.notify("This :W command doesn't support arguments for a new filename yet. Use :saveas for that.", vim.log.levels.WARN)
        return
    end
    local current_file = vim.fn.expand('%:p')
    if current_file == "" or vim.bo.buftype ~= "" or vim.bo.filetype == "gitcommit" then
        vim.notify("Cannot sudo write a buffer without a filename or a special buffer.", vim.log.levels.ERROR)
        return
    end
    local cmd = string.format("%%!sudo tee %s > /dev/null", vim.fn.shellescape(current_file))
    local preserve_view = vim.fn.winsaveview()
    vim.api.nvim_command(cmd)
    vim.fn.winrestview(preserve_view)
    -- Check if the command was successful by checking modification status
    -- This is a bit indirect. A direct check of tee's exit status is harder here.
    if vim.bo.modified then
        vim.notify("Sudo write might have failed. Buffer still modified.", vim.log.levels.WARN)
    else
        vim.notify("File saved with sudo.", vim.log.levels.INFO)
    end
    -- The original command has ':edit!' which reloads the file.
    -- This is important because 'tee' writes the file, but Vim's buffer might not know about external changes.
    vim.cmd('edit!')
  end,
  { nargs = "?", complete = "file" } -- Allows :W new_file (though current impl doesn't use new_file)
) 