vim.lsp.config('lua_ls', { settings = { Lua = {
    runtime = { version = 'LuaJIT' },
    workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME .. '/lua' } },
} } })
vim.lsp.enable({ 'nil_ls', 'lua_ls', 'bashls', 'nushell' })
