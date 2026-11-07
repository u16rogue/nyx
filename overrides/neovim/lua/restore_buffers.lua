-- AI-assisted: moved out of init.lua. Remembers closed file buffers once required;
-- restore() reopens the most recently closed one that still exists.
local closed_buffers = {}

vim.api.nvim_create_autocmd('BufDelete', {
    callback = function(args)
        local name = vim.api.nvim_buf_get_name(args.buf)
        if name ~= '' and vim.fn.filereadable(name) == 1 then
            table.insert(closed_buffers, name)
        end
    end,
})

local function restore()
    while #closed_buffers > 0 do
        local name = table.remove(closed_buffers)
        if vim.fn.filereadable(name) == 1 then
            vim.cmd('edit ' .. vim.fn.fnameescape(name))
            return
        end
    end

    vim.notify('No recently closed file buffer to restore', vim.log.levels.INFO)
end

return { restore = restore }
