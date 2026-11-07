-- AI-assisted: native status line, plain catppuccin blocks without separator glyphs:
-- [ mode ][ icon path ] diff ........ lsp diagnostics [ search branch ][ progress line:col format ]
-- Sets 'statusline' when required; the option calls back into render().
local C = require('catppuccin.palettes').get_palette('mocha')
-- letter + colour, looked up by the first two then the first character of the mode
local modes = {
    n = { 'N', C.blue }, no = { 'O', C.blue }, i = { 'I', C.green }, t = { 'T', C.green },
    v = { 'V', C.mauve }, V = { 'L', C.mauve }, ['\22'] = { 'B', C.mauve },
    s = { 'S', C.mauve }, S = { 'S', C.mauve }, ['\19'] = { 'S', C.mauve },
    R = { 'R', C.red }, c = { 'C', C.peach }, r = { 'P', C.peach }, ['!'] = { '!', C.peach },
}
local function current_mode()
    local m = vim.api.nvim_get_mode().mode
    return modes[m:sub(1, 2)] or modes[m:sub(1, 1)] or { m, C.blue }
end

local function set_highlights()
    local color = current_mode()[2]
    local hl = function(name, spec) vim.api.nvim_set_hl(0, name, spec) end
    hl('NyxSlA',     { fg = C.mantle, bg = color, bold = true })
    hl('NyxSlB',     { fg = color, bg = C.surface0 })
    hl('NyxSlC',     { fg = C.text, bg = C.mantle })
    hl('StatusLine', { fg = C.text, bg = C.mantle })
    for name, fg in pairs({ Error = C.red, Warn = C.yellow, Info = C.sky, Hint = C.teal }) do
        hl('NyxSlDiag' .. name, { fg = fg, bg = C.mantle })
    end
end

-- the filetype icon keeps its own colour on the B background, one group per colour
local icon_groups = {}
local function icon(name, ft)
    local glyph, color = require('nvim-web-devicons').get_icon_color(name, vim.fn.fnamemodify(name, ':e'), { default = true })
    if ft ~= '' then
        local by_ft, ft_color = require('nvim-web-devicons').get_icon_color_by_filetype(ft)
        glyph, color = by_ft or glyph, ft_color or color
    end
    local group = 'NyxSlIcon' .. color:gsub('#', '')
    if not icon_groups[group] then
        vim.api.nvim_set_hl(0, group, { fg = color, bg = C.surface0 })
        icon_groups[group] = true
    end
    return '%#' .. group .. '#' .. glyph .. ' %#NyxSlB#'
end

local function esc(s) return (s:gsub('%%', '%%%%')) end

local function render()
    local buf  = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
    local bo   = vim.bo[buf]
    local name = vim.api.nvim_buf_get_name(buf)
    local tree = bo.filetype == 'NvimTree'

    local path = tree and vim.fn.fnamemodify(vim.fn.getcwd(), ':~')
        or name == '' and '[No Name]'
        or vim.fn.fnamemodify(name, ':~')
    local flags = (bo.modified and ' \u{F044}' or '') .. ((bo.readonly or not bo.modifiable) and not tree and ' \u{EA75}' or '')

    local git = vim.b[buf].gitsigns_status_dict or {}
    local diff = {}
    for _, part in ipairs({ { '+', git.added }, { '~', git.changed }, { '-', git.removed } }) do
        if (part[2] or 0) > 0 then table.insert(diff, part[1] .. part[2]) end
    end

    local lsp = ''
    if not tree and bo.filetype ~= 'TelescopePrompt' then
        local names = vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({ bufnr = buf }))
        lsp = '\u{F085}  ' .. (#names == 0 and 'No Active LSP' or table.concat(names, ', '))
    end

    local diags, counts = {}, vim.diagnostic.count(buf)
    for _, d in ipairs({
        { vim.diagnostic.severity.ERROR, 'Error', '\u{F0159} ' }, { vim.diagnostic.severity.WARN, 'Warn', '\u{F071} ' },
        { vim.diagnostic.severity.INFO, 'Info', '\u{F05A} ' },    { vim.diagnostic.severity.HINT, 'Hint', '\u{F0335} ' },
    }) do
        if (counts[d[1]] or 0) > 0 then table.insert(diags, '%#NyxSlDiag' .. d[2] .. '#' .. d[3] .. counts[d[1]]) end
    end

    local search = ''
    if vim.v.hlsearch == 1 then
        local ok, s = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 120 })
        if ok and (s.total or 0) > 0 then
            search = s.incomplete == 2 and string.format('[%d/>%d] ', s.current, s.maxcount)
                or string.format('[%d/%d] ', s.current, s.total)
        end
    end
    local branch = vim.b[buf].gitsigns_head and ('• ' .. vim.b[buf].gitsigns_head) or ''

    local formats = { unix = '\u{E712}', dos = '\u{E70F}', mac = '\u{E711}' }

    return table.concat({
        '%#NyxSlA# ', current_mode()[1], ' ',
        '%#NyxSlB# ', icon(name, bo.filetype), esc(path), flags, ' ',
        '%#NyxSlC# ', table.concat(diff, ' '),
        '%=',
        esc(lsp), ' ', table.concat(diags, ' '), '%#NyxSlC# ',
        '%#NyxSlB# ', esc(search), esc(branch), ' ',
        '%#NyxSlA# %P %3l:%-2v ', formats[bo.fileformat] or '', ' ',
    })
end

vim.o.laststatus = 3
vim.o.statusline = "%!v:lua.require'statusline'.render()"

set_highlights()
vim.api.nvim_create_autocmd('ColorScheme', { callback = function() icon_groups = {}; set_highlights() end })
vim.api.nvim_create_autocmd('ModeChanged', { callback = function() set_highlights(); vim.cmd.redrawstatus() end })
vim.api.nvim_create_autocmd({ 'DiagnosticChanged', 'LspAttach', 'LspDetach' }, { command = 'redrawstatus' })
vim.api.nvim_create_autocmd('User', { pattern = 'GitSignsUpdate', command = 'redrawstatus' })

return { render = render }
