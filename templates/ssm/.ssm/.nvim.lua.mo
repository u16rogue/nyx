{{! THIS WAS WRITTEN BY A CLANKER: the project's neovim config, rendered into the project root by `ssm init` }}
-- snippets: .nvim/snippets/<filetype>.json (VS Code format)
vim.lsp.config('roc_ls', { cmd = { 'roc', 'experimental-lsp' }, root_markers = { 'main.roc', '.git' } })
vim.lsp.config('lua_ls', { settings = { Lua = {
    runtime = { version = 'LuaJIT' },
    workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME .. '/lua' } },
} } })

-- typescript 7+ is its own language server (`tsc --lsp`) and has no tsserver for ts_ls, so every js
-- project gets exactly one of them for the typescript in its node_modules. the native binary is
-- used directly as node_modules/.bin/tsc needs node
local function jsRootFind(bufnr)
    return vim.fs.root(bufnr, { 'bun.lock', 'bun.lockb', 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml' })
        or vim.fs.root(bufnr, '.git') or vim.fn.getcwd()
end
local function tscBinFind(root)
    return vim.fn.glob(vim.fs.joinpath(root, 'node_modules/@typescript/typescript-*/lib/tsc'), false, true)[1]
end
vim.lsp.config('tsc', {
    cmd = function(dispatchers, config)
        return vim.lsp.rpc.start({ tscBinFind(config.root_dir), '--lsp', '--stdio' }, dispatchers)
    end,
    root_dir = function(bufnr, on_dir)
        local root = jsRootFind(bufnr)
        if tscBinFind(root) then on_dir(root) end
    end,
})
vim.lsp.config('ts_ls', { root_dir = function(bufnr, on_dir)
    local root = jsRootFind(bufnr)
    if not tscBinFind(root) then on_dir(root) end
end })

vim.lsp.enable({
    'nil_ls', 'bashls', 'lua_ls',
    'clangd', 'zls', 'roc_ls', 'rust_analyzer',
    'tsc', 'ts_ls', 'svelte', 'html', 'cssls', 'jsonls',
    'basedpyright',
    'teal_ls',
})
