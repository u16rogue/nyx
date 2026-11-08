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
    hl('NyxSlRec',   { fg = C.mantle, bg = C.red, bold = true })
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

-- 'shortmess' q hides "recording @x"; shown here instead
local recording = ''

-- Messages that would draw over the status line ('cmdheight' 0) fill its free middle instead.
-- ui2 (experimental) takes over the message area; its msg_show is wrapped below so short
-- one-line messages land here and the rest (multi-line, prompts, pager) stays with ui2.
local message, message_text, message_id = '', '', 0
local message_groups = {} -- chunk highlights keep their fg on the C background
local function message_group(hl_id)
    local fg = (hl_id or 0) > 0 and vim.api.nvim_get_hl(0, { id = hl_id, link = false }).fg
    if not fg then return 'NyxSlC' end
    local group = string.format('NyxSlMsg%06x', fg)
    if not message_groups[group] then
        vim.api.nvim_set_hl(0, group, { fg = fg, bg = C.mantle })
        message_groups[group] = true
    end
    return group
end

local function set_message(content, append)
    local text, parts = append and message_text or '', { append and message or '' }
    for _, chunk in ipairs(content or {}) do
        text = text .. chunk[2]
        table.insert(parts, '%#' .. message_group(chunk[3]) .. '#' .. esc(chunk[2]))
    end
    if text:find('\n') or vim.api.nvim_strwidth(text) > vim.o.columns / 2 then return false end
    message, message_text, message_id = table.concat(parts), text, message_id + 1
    local id = message_id
    vim.cmd.redrawstatus()
    if text ~= '' then
        vim.defer_fn(function()
            if id == message_id then set_message() end
        end, 4000)
    end
    return true
end

local function hook_messages()
    local ok, ui2 = pcall(require, 'vim._core.ui2')
    if not ok then return end
    ui2.enable({ msg = { targets = 'msg' } })
    local msgs = ui2.msg -- nil without a UI (headless)
    if not (msgs and type(msgs.msg_show) == 'function') then return end
    local msg_show = msgs.msg_show
    local keep = { confirm = true, return_prompt = true, wildlist = true, search_cmd = true, search_count = true }
    msgs.msg_show = function(kind, content, replace_last, history, append, id, trigger)
        local cmd = ui2.cmd or {}
        local busy = cmd.prompt or (cmd.level or 0) > 0 or vim.api.nvim_get_current_win() == ui2.wins.pager
        if kind == 'empty' then
            pcall(set_message)
        elseif not busy and not keep[kind] then
            local handled, shown = pcall(set_message, content, append)
            if handled and shown then return end
        end
        return msg_show(kind, content, replace_last, history, append, id, trigger)
    end
end

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
        recording ~= '' and ('%#NyxSlRec# @' .. esc(recording) .. ' ') or '',
        '%#NyxSlB# ', icon(name, bo.filetype), esc(path), flags, ' ',
        '%#NyxSlC# ', table.concat(diff, ' '),
        message ~= '' and (' ' .. message .. '%#NyxSlC#') or '',
        '%=',
        esc(lsp), ' ', table.concat(diags, ' '), '%#NyxSlC# ',
        '%#NyxSlB# ', esc(search), esc(branch), ' ',
        '%#NyxSlA# %P %3l:%-2v ', formats[bo.fileformat] or '', ' ',
    })
end

vim.o.laststatus = 3
vim.o.statusline = "%!v:lua.require'statusline'.render()"
vim.opt.shortmess:append('q')
hook_messages()

vim.api.nvim_create_autocmd('RecordingEnter', { callback = function() recording = vim.fn.reg_recording(); vim.cmd.redrawstatus() end })
vim.api.nvim_create_autocmd('RecordingLeave', { callback = function() recording = ''; vim.cmd.redrawstatus() end })

set_highlights()
vim.api.nvim_create_autocmd('ColorScheme', { callback = function() icon_groups = {}; message_groups = {}; set_highlights() end })
vim.api.nvim_create_autocmd('ModeChanged', { callback = function() set_highlights(); vim.cmd.redrawstatus() end })
vim.api.nvim_create_autocmd({ 'DiagnosticChanged', 'LspAttach', 'LspDetach' }, { command = 'redrawstatus' })
vim.api.nvim_create_autocmd('User', { pattern = 'GitSignsUpdate', command = 'redrawstatus' })

return { render = render }
