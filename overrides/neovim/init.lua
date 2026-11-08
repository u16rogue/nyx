local function map(mode, lhs, rhs, desc, opts)
    vim.keymap.set(mode, lhs, rhs, vim.tbl_extend('force', { silent = true, desc = desc }, opts or {}))
end

vim.g.mapleader      = ' '
vim.g.maplocalleader = ','

-- [[ Options ]]
vim.o.tabstop        = 4
vim.o.softtabstop    = 4
vim.o.shiftwidth     = 4
vim.o.expandtab      = true
vim.o.autoindent     = true
vim.o.copyindent     = true
vim.o.cmdheight      = 0
vim.o.showmode       = false
vim.o.signcolumn     = 'yes' -- space before line numbers
vim.o.showmatch      = true
vim.o.termguicolors  = true
vim.o.linebreak      = true
vim.o.wrap           = true
vim.o.cursorline     = true
vim.o.cursorlineopt  = 'number'
vim.o.number         = true
vim.o.relativenumber = true
vim.o.ignorecase     = true
vim.o.smartcase      = true
vim.o.undofile       = true
vim.o.swapfile       = false
vim.o.writebackup    = false
vim.o.splitbelow     = true
vim.o.splitright     = true
vim.o.mouse          = 'nvi'
vim.o.timeoutlen     = 500
vim.o.updatetime     = 250
vim.o.pumheight      = 10
vim.o.list           = true
vim.opt.listchars    = { space = '⋅', eol = '↴' }
vim.o.exrc           = true -- trusted project-local .nvim.lua (see README.md)

vim.diagnostic.config({
    virtual_text  = true,
    severity_sort = true,
})

-- [[ Small behaviours ]]

vim.api.nvim_create_autocmd('TextYankPost', {
    callback = function()
        if vim.v.event.operator == 'y' then
            require('vim.ui.clipboard.osc52').copy('+')(vim.v.event.regcontents)
        end
    end,
})

-- auto create .nvimsession
vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
        local session_path = vim.fn.getcwd() .. '/.nvimsession'
        if vim.fn.filereadable(session_path) == 1 then
            vim.cmd('mksession! .nvimsession')
        end
    end,
})

-- word wrap fix
---@diagnostic disable-next-line: unused-local
for _k, v in pairs({ 'j', 'k' }) do
    vim.keymap.set('n', v, 'v:count == 0 ? "g' .. v .. '" : "' .. v .. '"', { expr = true, silent = true })
end

-- [[ Theme ]]
require('catppuccin').setup({
    flavour = 'mocha',
    custom_highlights = function(c)
        -- rainbow colours faded toward the background: 0 = invisible, 1 = full colour
        local rainbow_dim = { indent = 0.35, delimiter = 0.9 }
        local rainbow = { Red = 'red', Yellow = 'yellow', Blue = 'blue', Orange = 'peach', Green = 'green', Violet = 'mauve', Cyan = 'teal' }
        local blend = require('catppuccin.utils.colors').blend
        local hl = { CursorLineNr = { fg = '#ffffff' } }
        for name, color in pairs(rainbow) do
            hl['Rainbow' .. name]          = { fg = blend(c[color], c.base, rainbow_dim.indent) }
            hl['RainbowDelimiter' .. name] = { fg = blend(c[color], c.base, rainbow_dim.delimiter) }
        end
        return hl
    end,
})
vim.cmd.colorscheme('catppuccin')

-- [[ Tree-sitter ]]
-- Highlighting/indent are native. Common grammars come from package.nix, language ones from the
-- project devshell (`share/nvim/site/parser` via XDG_DATA_DIRS). `van`/`vin` grow/shrink the selection.
vim.treesitter.language.register('bash', { 'ash', 'dash' })
vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
        if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
    end,
})
require('treesitter-context').setup({ separator = '-' })
require('nvim-ts-autotag').setup()

-- [[ Status line ]]
require('statusline')

-- [[ Buffer line ]]
require('bufferline').setup({
    highlights = require('catppuccin.special.bufferline').get_theme(),
    options = {
        close_command           = function(bufnr) require('bufdelete').bufdelete(bufnr, false) end,
        numbers                 = function(opts) return string.format('%s·%s', opts.raise(opts.id), opts.lower(opts.ordinal)) end,
        indicator               = { style = 'none' },
        diagnostics             = 'nvim_lsp',
        show_buffer_close_icons = false,
        show_close_icon         = false,
        sort_by                 = 'extension',
        offsets                 = { { filetype = 'NvimTree', text = 'File Explorer', highlight = 'Directory', separator = true } },
    },
})
map('n', '<A-c>', function() require('bufdelete').bufdelete(0, false) end, 'Close buffer')
map('n', '<A-x>', '<Cmd>BufferLineCycleNext<CR>', 'Next buffer')
map('n', '<A-z>', '<Cmd>BufferLineCyclePrev<CR>', 'Previous buffer')
map('n', '<A-S-x>', '<Cmd>BufferLineMoveNext<CR>', 'Move buffer right')
map('n', '<A-S-z>', '<Cmd>BufferLineMovePrev<CR>', 'Move buffer left')
map('n', '<A-S-c>', require('restore_buffers').restore, 'Restore last closed buffer') -- restore buffers

-- [[ File tree ]]
vim.g.loaded_netrw       = 1
vim.g.loaded_netrwPlugin = 1
require('nvim-tree').setup({
    disable_netrw = true,
    renderer = {
        group_empty    = true,
        indent_width   = 2,
        indent_markers = { enable = true, inline_arrows = false },
        icons = {
            show = { git = true },
            git_placement = 'right_align',
            glyphs = { git = {
                deleted   = '\u{F458}',
                ignored   = '◌',
                renamed   = '➜',
                staged    = '✓',
                unmerged  = '\u{E727}',
                unstaged  = '✗',
                untracked = '★',
            } },
        },
    },
    view = {
        signcolumn = 'yes',
        number     = true,
        float      = { enable = true, open_win_config = { width = 80, height = 100 } },
    },
    git      = { enable = true, ignore = false },
    modified = { enable = true },
    filters  = { dotfiles = false },
})
map('n', '<F1>', '<Cmd>NvimTreeToggle<CR>',      'Toggle file tree')
map('i', '<F1>', '<Esc><Cmd>NvimTreeToggle<CR>', 'Toggle file tree')

-- [[ Telescope ]]
do
    local telescope = require('telescope')
    telescope.setup({
        defaults = {
            prompt_prefix        = '  \u{F422}  ',
            selection_caret      = '  ',
            entry_prefix         = '  ',
            sorting_strategy     = 'ascending',
            layout_strategy      = 'horizontal',
            layout_config        = { width = 0.8, height = 0.8, preview_cutoff = 120, horizontal = { prompt_position = 'top', preview_width = 0.55 } },
            path_display         = { 'absolute' },
            file_ignore_patterns = { 'node_modules', '%.git/', 'dist/', 'build/', 'target/', 'result/' },
            vimgrep_arguments    = { 'rg', '--color=never', '--no-heading', '--with-filename', '--line-number', '--column', '--smart-case', '--hidden', '--no-ignore' },
            mappings = { i = {
                ['<C-d>'] = 'move_selection_next',
                ['<C-e>'] = 'move_selection_previous',
                ['<C-f>'] = 'select_default',
            } },
        },
        pickers = { find_files = { find_command = { 'fd', '--type=file' } } },
    })
    telescope.load_extension('fzf')
    telescope.load_extension('ui-select')

    for lhs, picker in pairs({
        ['<leader>ff']   = 'find_files',
        ['<leader>fg']   = 'live_grep',
        ['<leader>fb']   = 'buffers',
        ['<leader>fh']   = 'help_tags',
        ['<leader>ft']   = 'builtin',
        ['<leader>fr']   = 'resume',
        ['<leader>fs']   = 'treesitter',
        ['gd']           = 'lsp_definitions',
    }) do
        map('n', lhs, function() require('telescope.builtin')[picker]() end, 'Telescope ' .. picker)
    end
end

-- [[ Git ]]
require('gitsigns').setup({
    signs = {
        add          = { text = '+' },
        change       = { text = '~' },
        delete       = { text = '_' },
        topdelete    = { text = '‾' },
        changedelete = { text = '~' },
    },
})

-- [[ Scope / indent visuals ]]
-- rainbow-delimiters needs no setup; colours (and dimness) are set in the theme section
require('ibl').setup({
    indent = {
        char = '┊',
        highlight = { 'RainbowRed', 'RainbowYellow', 'RainbowBlue', 'RainbowOrange', 'RainbowGreen', 'RainbowViolet', 'RainbowCyan' },
    },
    scope = { enabled = false },
})

-- [[ Editing helpers ]]
require('treesj').setup({ use_default_keymaps = false })
map('n', '<leader>as', '<Cmd>TSJToggle<CR>', 'Split/join scope')
map('x', '<leader>aa', '<Plug>(EasyAlign)', 'Align')
require('nvim-surround').setup() -- visual `S(` wrap, `ys{motion}(` add, `cs"'` change, `ds(` delete

-- [[ Completion + snippets ]]
require('blink.cmp').setup({
    keymap = {
        preset = 'none',
        ['<C-d>'] = { 'select_next', 'snippet_forward', function(cmp)
            local col = vim.fn.col('.') - 1
            if col > 0 and vim.fn.getline('.'):sub(col, col):match('%S') then return cmp.show() end
        end, 'fallback' },
        ['<C-e>']   = { 'select_prev', 'snippet_backward', 'fallback' },
        ['<C-f>']   = { 'accept', 'fallback' },
        ['<C-S-d>'] = { 'scroll_documentation_down', 'fallback' },
        ['<C-S-e>'] = { 'scroll_documentation_up', 'fallback' },
    },
    completion = {
        list          = { selection = { preselect = true, auto_insert = false } },
        menu          = { border = 'rounded' },
        documentation = { auto_show = true, auto_show_delay_ms = 250, window = { border = 'rounded' } },
    },
    sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
        providers = {
            snippets = { opts = { search_paths =
                vim.fs.find('.nvim/snippets', { upward = true, type = 'directory', path = vim.fn.getcwd() }) } },
        },
    },
    fuzzy = { prebuilt_binaries = { download = false } },
})

-- [[ LSP ]]

do
    local function diagnostic_jump(count)
        return function()
            vim.diagnostic.jump({
                count   = count,
                on_jump = function(_, bufnr) vim.diagnostic.open_float({ scope = 'cursor', bufnr = bufnr, focus = false }) end,
            })
        end
    end

    vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
            local function bmap(lhs, rhs, desc) map('n', lhs, rhs, desc, { buffer = args.buf }) end
            bmap('K',           vim.lsp.buf.hover,               'Hover')
            bmap('<F2>',        vim.lsp.buf.rename,              'Rename symbol')
            bmap(']',           diagnostic_jump(1),              'Next diagnostic')
            bmap('[',           diagnostic_jump(-1),             'Previous diagnostic')
            bmap('\\',          vim.diagnostic.open_float,       'Diagnostic float')
            bmap('<leader>la',  vim.lsp.buf.code_action,         'Code action')
        end,
    })
end
