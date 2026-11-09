{{! THIS WAS WRITTEN BY A CLANKER: the project's neovim config, rendered into the project root by `ssm init` }}
-- snippets: .nvim/snippets/<filetype>.json (VS Code format)
vim.lsp.config('roc_ls', { cmd = { 'roc', 'experimental-lsp' }, root_markers = { 'main.roc', '.git' } })
vim.lsp.config('lua_ls', { settings = { Lua = {
    runtime = { version = 'LuaJIT' },
    workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME .. '/lua' } },
} } })
vim.lsp.enable({
    'nil_ls', 'bashls', 'lua_ls',
    'clangd', 'zls', 'roc_ls', 'rust_analyzer',
    'ts_ls', 'svelte', 'html', 'cssls', 'jsonls',
    'basedpyright',
    'teal_ls',
})
