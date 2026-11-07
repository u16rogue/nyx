{{! THIS WAS WRITTEN BY A CLANKER: the project's neovim config, rendered into the project root by `ssm init` }}
-- run by neovim once `:trust`ed ('exrc'). a server only starts if its binary is on PATH,
-- which the subprojects' shell.nix provide, so the unused ones cost nothing.
-- snippets: .nvim/snippets/<filetype>.json (VS Code format)
vim.lsp.config('roc_ls', { cmd = { 'roc', 'experimental-lsp' }, root_markers = { 'main.roc', '.git' } })
vim.lsp.enable({
    'nil_ls', 'bashls',
    'clangd', 'zls', 'roc_ls', 'rust_analyzer',
    'ts_ls', 'svelte', 'html', 'cssls', 'jsonls',
    'basedpyright',
})
