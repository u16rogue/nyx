-- The diagram model. The buffer text is the only thing that is stored: modelParse finds boxes and
-- lines in the box drawing characters, everything else is background. A frame is a modified copy of
-- a parsed model, frameRender turns it back into text for the rows that changed.
--
-- Cells are display columns, x and y are 0-based. Every cell of a shape carries a mask of the
-- directions it connects in, overlapping shapes OR their masks which is what makes a crossing a `┼`.
local M = {}

local bit = require('bit')
local band, bor, bnot = bit.band, bit.bor, bit.bnot

local U, D, L, R = 1, 2, 4, 8
local DIRS = { U, D, L, R }
local OPP  = { [U] = D, [D] = U, [L] = R, [R] = L }
local DX   = { [U] = 0, [D] = 0, [L] = -1, [R] = 1 }
local DY   = { [U] = -1, [D] = 1, [L] = 0, [R] = 0 }
local PERP = { [U] = { L, R }, [D] = { L, R }, [L] = { U, D }, [R] = { U, D } }
local POPCOUNT = {}
for mask = 0, 15 do
    POPCOUNT[mask] = band(mask, 1) + band(mask, 2) / 2 + band(mask, 4) / 4 + band(mask, 8) / 8
end

M.STYLES = { 'light', 'rounded', 'heavy', 'double' }

local function charsetBuild(h, v, tl, tr, bl, br, tee_r, tee_l, tee_d, tee_u, cross)
    return {
        [L + R] = h, [L] = h, [R] = h, [U + D] = v, [U] = v, [D] = v,
        [D + R] = tl, [D + L] = tr, [U + R] = bl, [U + L] = br,
        [U + D + R] = tee_r, [U + D + L] = tee_l, [D + L + R] = tee_d, [U + L + R] = tee_u,
        [U + D + L + R] = cross,
    }
end

local CHARS = {
    light   = charsetBuild('─', '│', '┌', '┐', '└', '┘', '├', '┤', '┬', '┴', '┼'),
    rounded = charsetBuild('─', '│', '╭', '╮', '╰', '╯', '├', '┤', '┬', '┴', '┼'),
    heavy   = charsetBuild('━', '┃', '┏', '┓', '┗', '┛', '┣', '┫', '┳', '┻', '╋'),
    double  = charsetBuild('═', '║', '╔', '╗', '╚', '╝', '╠', '╣', '╦', '╩', '╬'),
}

-- char -> { mask, style }. light goes last so the chars rounded shares with it read as light.
local BITS = {}
for _, style in ipairs({ 'double', 'heavy', 'rounded', 'light' }) do
    for mask, ch in pairs(CHARS[style]) do
        if POPCOUNT[mask] > 1 then BITS[ch] = { mask = mask, style = style } end
    end
end

-- Arrow heads by the direction they point in. The ascii family is only read as a head when a line
-- runs into it.
local HEAD_FAMILIES = {
    { [R] = '▶', [L] = '◀', [U] = '▲', [D] = '▼' },
    { [R] = '►', [L] = '◄', [U] = '▲', [D] = '▼' },
    { [R] = '>', [L] = '<', [U] = '^', [D] = 'v' },
}
local HEADS = {}
for family = 2, 1, -1 do
    for dir, ch in pairs(HEAD_FAMILIES[family]) do HEADS[ch] = { dir = dir, family = family } end
end

local function dirBetween(a, b)
    if b[1] > a[1] then return R elseif b[1] < a[1] then return L end
    if b[2] > a[2] then return D elseif b[2] < a[2] then return U end
    return nil
end

-- [[ Cells ]]

local width_cache = {}
local function charWidth(ch)
    local byte = ch:byte()
    if #ch == 1 and byte >= 32 and byte < 127 then return 1 end
    local width = width_cache[ch]
    if not width then
        width = vim.fn.strdisplaywidth(ch)
        width_cache[ch] = width
    end
    return width
end

-- One entry per display column: the char that starts there, or false for the columns a wide char or
-- a tab continues into.
function M.lineCells(s, tabstop)
    local cells, n = {}, 0
    for ch in s:gmatch('.[\128-\191]*') do
        local width
        if ch == '\t' then width = tabstop - n % tabstop else width = charWidth(ch) end
        if width == 0 then
            local i = n
            while cells[i] == false do i = i - 1 end
            if i > 0 then cells[i] = cells[i] .. ch end
        else
            cells[n + 1] = ch
            for i = 2, width do cells[n + i] = false end
            n = n + width
        end
    end
    return cells
end

-- Byte offset of column x in a line's cells, nil past the end of the line.
function M.cellsByte(cells, x)
    if x >= #cells then return nil end
    local offset = 0
    for i = 1, x do
        if cells[i] then offset = offset + #cells[i] end
    end
    return offset
end

local function cellsPut(cells, x, ch)
    if ch == '\t' then ch = ' ' end
    local width = math.max(charWidth(ch), 1)
    for i = #cells + 1, x do cells[i] = ' ' end
    -- a wide char or a tab that is only partly covered turns into spaces
    for i = x + 1, x + width do
        if cells[i] ~= nil then
            local first = i
            while cells[first] == false do first = first - 1 end
            cells[first] = ' '
            local rest = first + 1
            while cells[rest] == false do
                cells[rest] = ' '
                rest = rest + 1
            end
        end
    end
    cells[x + 1] = ch
    for i = 2, width do cells[x + i] = false end
end

local function cellsString(cells)
    local parts = {}
    for i = 1, #cells do
        if cells[i] then parts[#parts + 1] = cells[i] end
    end
    return (table.concat(parts):gsub(' +$', ''))
end

function M.modelCells(model, y)
    local cells = model.cells[y]
    if not cells then
        cells = M.lineCells(model.text[y + 1] or '', model.tabstop)
        model.cells[y] = cells
    end
    return cells
end

-- A row without the cells that belong to shapes.
local function modelBackground(model, y)
    local cells = model.bg[y]
    if not cells then
        cells = {}
        for i, ch in ipairs(M.modelCells(model, y)) do cells[i] = ch end
        for x in pairs(model.claimed[y] or {}) do cells[x + 1] = ' ' end
        model.bg[y] = cells
    end
    return cells
end

-- [[ Shapes ]]
-- box:  { kind = 'box', x, y, w, h, style }
-- line: { kind = 'line', pts, style, head = { family|false, family|false }, anchor = { Anchor|false, Anchor|false } }
-- Anchor: { box, side = 'l'|'r'|'t'|'b', off, on }. off counts along the side from the box's top
-- left, on is true when the line ends on the border cell instead of next to it.

local SIDE_NORMAL = { l = { -1, 0 }, r = { 1, 0 }, t = { 0, -1 }, b = { 0, 1 } }
-- the side a line moving in a direction runs into
local SIDE_FACING = { [R] = 'l', [L] = 'r', [D] = 't', [U] = 'b' }

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

-- The cell a line attached with this anchor ends in, and the side's outward normal.
function M.anchorPoint(anchor)
    local box, normal = anchor.box, SIDE_NORMAL[anchor.side]
    local x, y
    if anchor.side == 'l' or anchor.side == 'r' then
        x = anchor.side == 'l' and box.x or box.x + box.w - 1
        y = box.y + clamp(anchor.off, 0, box.h - 1)
    else
        x = box.x + clamp(anchor.off, 0, box.w - 1)
        y = anchor.side == 't' and box.y or box.y + box.h - 1
    end
    if not anchor.on then x, y = x + normal[1], y + normal[2] end
    return { x, y }, normal
end

local function boxSideOffset(box, side, x, y)
    if side == 'l' and x == box.x and y >= box.y and y < box.y + box.h then return y - box.y end
    if side == 'r' and x == box.x + box.w - 1 and y >= box.y and y < box.y + box.h then return y - box.y end
    if side == 't' and y == box.y and x >= box.x and x < box.x + box.w then return x - box.x end
    if side == 'b' and y == box.y + box.h - 1 and x >= box.x and x < box.x + box.w then return x - box.x end
    return nil
end

-- The anchor a line end at p has when it got there moving in dir: the cell ahead of it, or the one
-- it sits on, is on the side of a box that faces it.
local function anchorDetect(shapes, p, dir)
    local side = SIDE_FACING[dir]
    local found
    for _, box in ipairs(shapes) do
        if box.kind == 'box' and (not found or box.w * box.h < found.box.w * found.box.h) then
            local off = boxSideOffset(box, side, p[1] + DX[dir], p[2] + DY[dir])
            if off then
                found = { box = box, side = side, off = off, on = false }
            else
                off = boxSideOffset(box, side, p[1], p[2])
                if off then found = { box = box, side = side, off = off, on = true } end
            end
        end
    end
    return found
end

-- Identifies a shape by what it looks like. geometry_only leaves the style and the heads out: a
-- style that doesn't show, like rounded on a line without corners, doesn't survive the text.
function M.shapeKey(shape, geometry_only)
    if shape.kind == 'box' then
        return ('b:%d:%d:%d:%d:%s'):format(shape.x, shape.y, shape.w, shape.h, geometry_only and '' or shape.style)
    end
    local parts = { 'l' }
    if not geometry_only then
        parts = { 'l', shape.style, tostring(shape.head[1]), tostring(shape.head[2]) }
    end
    for _, p in ipairs(shape.pts) do parts[#parts + 1] = p[1] .. ',' .. p[2] end
    return table.concat(parts, ':')
end

function M.shapeCopy(shape)
    if shape.kind == 'box' then
        return { kind = 'box', x = shape.x, y = shape.y, w = shape.w, h = shape.h, style = shape.style }
    end
    local pts = {}
    for i, p in ipairs(shape.pts) do pts[i] = { p[1], p[2] } end
    return {
        kind = 'line', pts = pts, style = shape.style,
        head = { shape.head[1], shape.head[2] }, anchor = { shape.anchor[1], shape.anchor[2] },
    }
end

-- x1, y1, x2, y2
function M.shapeBounds(shape)
    if shape.kind == 'box' then
        return shape.x, shape.y, shape.x + shape.w - 1, shape.y + shape.h - 1
    end
    local x1, y1, x2, y2 = math.huge, math.huge, -1, -1
    for _, p in ipairs(shape.pts) do
        x1, y1, x2, y2 = math.min(x1, p[1]), math.min(y1, p[2]), math.max(x2, p[1]), math.max(y2, p[2])
    end
    return x1, y1, x2, y2
end

function M.shapeTranslate(shape, dx, dy)
    if shape.kind == 'box' then
        shape.x, shape.y = shape.x + dx, shape.y + dy
    else
        for _, p in ipairs(shape.pts) do p[1], p[2] = p[1] + dx, p[2] + dy end
    end
end

-- Calls fn(x, y, mask) for every cell of a shape. A cell shared by two segments is visited once per segment.
local function shapeWalk(shape, fn)
    if shape.kind == 'box' then
        local x1, y1, x2, y2 = M.shapeBounds(shape)
        fn(x1, y1, D + R)
        fn(x2, y1, D + L)
        fn(x1, y2, U + R)
        fn(x2, y2, U + L)
        for x = x1 + 1, x2 - 1 do
            fn(x, y1, L + R)
            fn(x, y2, L + R)
        end
        for y = y1 + 1, y2 - 1 do
            fn(x1, y, U + D)
            fn(x2, y, U + D)
        end
        return
    end
    for i = 1, #shape.pts - 1 do
        local a, b = shape.pts[i], shape.pts[i + 1]
        local dir = dirBetween(a, b)
        local x, y = a[1], a[2]
        while x ~= b[1] or y ~= b[2] do
            fn(x, y, dir)
            x, y = x + DX[dir], y + DY[dir]
            fn(x, y, OPP[dir])
        end
    end
end

-- The cells a shape occupies as a list of { x, y }.
function M.shapeCells(shape)
    local cells, seen = {}, {}
    shapeWalk(shape, function(x, y)
        local key = x .. ',' .. y
        if not seen[key] then
            seen[key] = true
            cells[#cells + 1] = { x, y }
        end
    end)
    return cells
end

-- [[ Parse ]]

local function gridGet(grid, x, y)
    local row = grid[y]
    return row and row[x] or 0
end

local function gridSet(grid, x, y, value)
    local row = grid[y]
    if not row then
        row = {}
        grid[y] = row
    end
    row[x] = value
end

function M.modelParse(lines, tabstop)
    local model = { text = lines, nrows = #lines, tabstop = tabstop, cells = {}, bg = {}, claimed = {}, shapes = {} }

    local mask, style_at, head_at = {}, {}, {}
    local order = {} -- the cells that carry a mask, row major
    for y = 0, #lines - 1 do
        -- every box drawing char and arrow head starts with this byte, other rows are never split into cells
        if lines[y + 1]:find('\226', 1, true) then
            for i, ch in ipairs(M.modelCells(model, y)) do
                local bits = ch and BITS[ch]
                local head = ch and HEADS[ch]
                if bits then
                    gridSet(mask, i - 1, y, bits.mask)
                    gridSet(style_at, i - 1, y, bits.style)
                    order[#order + 1] = { i - 1, y }
                elseif head then
                    gridSet(mask, i - 1, y, OPP[head.dir])
                    gridSet(head_at, i - 1, y, head.family)
                    order[#order + 1] = { i - 1, y }
                end
            end
        end
    end

    -- ascii heads: a line char that points at nothing but a matching `>`, `<`, `^` or `v`
    do
        local found = {}
        for _, cell in ipairs(order) do
            local x, y = cell[1], cell[2]
            if gridGet(head_at, x, y) == 0 then
                for _, dir in ipairs(DIRS) do
                    local nx, ny = x + DX[dir], y + DY[dir]
                    if band(mask[y][x], dir) ~= 0 and nx >= 0 and ny >= 0 and gridGet(mask, nx, ny) == 0 then
                        local cells = M.modelCells(model, ny)
                        local is_head = cells[nx + 1] == HEAD_FAMILIES[3][dir]
                        if is_head and dir == D then
                            -- a `v` is only a head when it stands alone
                            local left, right = cells[nx], cells[nx + 2]
                            is_head = (left == nil or left == ' ') and (right == nil or right == ' ')
                        end
                        if is_head then found[#found + 1] = { nx, ny, OPP[dir] } end
                    end
                end
            end
        end
        for _, cell in ipairs(found) do
            if gridGet(mask, cell[1], cell[2]) == 0 then
                gridSet(mask, cell[1], cell[2], cell[3])
                gridSet(head_at, cell[1], cell[2], 3)
                order[#order + 1] = { cell[1], cell[2] }
            end
        end
    end

    -- what is left of each mask once the shapes found so far took their part
    local rest = {}
    for y, row in pairs(mask) do
        rest[y] = {}
        for x, value in pairs(row) do rest[y][x] = value end
    end

    local function restTake(x, y, bits)
        rest[y][x] = band(rest[y][x], bnot(bits))
        gridSet(model.claimed, x, y, true)
    end
    local function connected(x, y, dir)
        return band(gridGet(rest, x, y), dir) ~= 0 and band(gridGet(rest, x + DX[dir], y + DY[dir]), OPP[dir]) ~= 0
    end

    -- boxes: the smallest closed rectangle hanging off each top left corner
    local function boxFind(x, y)
        local x2 = x
        while connected(x2, y, R) do
            x2 = x2 + 1
            if band(gridGet(rest, x2, y), D) ~= 0 then
                local y2 = y
                while connected(x, y2, D) and connected(x2, y2, D) do
                    y2 = y2 + 1
                    local closed = band(gridGet(rest, x, y2), R) ~= 0 and band(gridGet(rest, x2, y2), L) ~= 0
                    for edge_x = x, x2 - 1 do
                        if not closed then break end
                        closed = connected(edge_x, y2, R)
                    end
                    if closed then return x2, y2 end
                end
            end
        end
        return nil
    end
    for _, cell in ipairs(order) do
        local x, y = cell[1], cell[2]
        if band(gridGet(rest, x, y), D + R) == D + R then
            local x2, y2 = boxFind(x, y)
            if x2 then
                local box = { kind = 'box', x = x, y = y, w = x2 - x + 1, h = y2 - y + 1, style = gridGet(style_at, x, y) }
                if box.style == 0 then box.style = 'light' end
                shapeWalk(box, restTake)
                model.shapes[#model.shapes + 1] = box
            end
        end
    end

    -- lines: followed from every cell that has exactly one connection left
    local function lineTrace(x, y, dir)
        local pts = { { x, y } }
        local style = gridGet(style_at, x, y)
        while true do
            restTake(x, y, dir)
            x, y = x + DX[dir], y + DY[dir]
            restTake(x, y, OPP[dir])
            if style == 0 then style = gridGet(style_at, x, y) end
            if not connected(x, y, dir) then
                -- a junction ends the line that runs into it sideways, the one going straight continues
                if POPCOUNT[gridGet(mask, x, y)] >= 3 then break end
                local turn, turns = nil, 0
                for _, side in ipairs(PERP[dir]) do
                    if connected(x, y, side) then turn, turns = side, turns + 1 end
                end
                if turns ~= 1 then break end
                if gridGet(style_at, x, y) == 'rounded' then style = 'rounded' end
                pts[#pts + 1] = { x, y }
                dir = turn
            end
        end
        pts[#pts + 1] = { x, y }
        local first, last = pts[1], pts[#pts]
        local head_first, head_last = gridGet(head_at, first[1], first[2]), gridGet(head_at, last[1], last[2])
        model.shapes[#model.shapes + 1] = {
            kind = 'line', pts = pts, style = style ~= 0 and style or 'light',
            head = { head_first ~= 0 and head_first, head_last ~= 0 and head_last },
            anchor = { false, false },
        }
    end
    local traced
    repeat
        traced = false
        for _, cell in ipairs(order) do
            local x, y = cell[1], cell[2]
            local only, count = nil, 0
            for _, dir in ipairs(DIRS) do
                if connected(x, y, dir) then only, count = dir, count + 1 end
            end
            if count == 1 then
                lineTrace(x, y, only)
                traced = true
            end
        end
    until not traced

    for _, line in ipairs(model.shapes) do
        if line.kind == 'line' then
            local n = #line.pts
            line.anchor[1] = anchorDetect(model.shapes, line.pts[1], dirBetween(line.pts[2], line.pts[1])) or false
            line.anchor[2] = anchorDetect(model.shapes, line.pts[n], dirBetween(line.pts[n - 1], line.pts[n])) or false
        end
    end

    return model
end

-- [[ Frames ]]
-- { base, shapes, bgmove = { x1, y1, x2, y2, dx, dy }, bgclear = { x1, y1, x2, y2 } }
-- bgmove carries the background of a rect along, bgclear blanks one.

-- A frame with a copy of every shape, plus the list of copies in the order of base.shapes.
function M.modelFork(base)
    local copies, by_shape = {}, {}
    for i, shape in ipairs(base.shapes) do
        copies[i] = M.shapeCopy(shape)
        by_shape[shape] = copies[i]
    end
    for _, copy in ipairs(copies) do
        if copy.kind == 'line' then
            for i = 1, 2 do
                local anchor = copy.anchor[i]
                if anchor then
                    copy.anchor[i] = { box = by_shape[anchor.box], side = anchor.side, off = anchor.off, on = anchor.on }
                end
            end
        end
    end
    local shapes = {}
    for i, copy in ipairs(copies) do shapes[i] = copy end
    return { base = base, shapes = shapes }, copies
end

-- The text of every row the frame changes, { [y] = string }.
function M.frameRender(frame)
    local base = frame.base
    local dirty = {}
    local function rowsMark(y1, y2)
        for y = math.max(y1, 0), y2 do dirty[y] = true end
    end

    -- the rows of every shape that has no identical counterpart on the other side
    local function shapesDiff(shapes, others)
        local counts = {}
        for _, shape in ipairs(others) do
            local key = M.shapeKey(shape)
            counts[key] = (counts[key] or 0) + 1
        end
        for _, shape in ipairs(shapes) do
            local key = M.shapeKey(shape)
            if (counts[key] or 0) > 0 then
                counts[key] = counts[key] - 1
            else
                local _, y1, _, y2 = M.shapeBounds(shape)
                rowsMark(y1, y2)
            end
        end
    end
    shapesDiff(base.shapes, frame.shapes)
    shapesDiff(frame.shapes, base.shapes)

    local move, clear = frame.bgmove, frame.bgclear
    if move then
        rowsMark(move[2], move[4])
        rowsMark(move[2] + move[6], move[4] + move[6])
    end
    if clear then rowsMark(clear[2], clear[4]) end

    -- every shape drawn into { [y] = { [x] = { mask, style, char } } }
    local raster = {}
    for _, shape in ipairs(frame.shapes) do
        if shape.kind == 'box' or #shape.pts >= 2 then
            shapeWalk(shape, function(x, y, bits)
                if x < 0 or y < 0 or not dirty[y] then return end
                local row = raster[y]
                if not row then
                    row = {}
                    raster[y] = row
                end
                local cell = row[x]
                if not cell then
                    cell = { mask = 0 }
                    row[x] = cell
                end
                cell.mask, cell.style = bor(cell.mask, bits), shape.style
            end)
            if shape.kind == 'line' then
                local n = #shape.pts
                for i, tip in ipairs({ shape.pts[1], shape.pts[n] }) do
                    local family = shape.head[i]
                    local cell = family and raster[tip[2]] and raster[tip[2]][tip[1]]
                    if cell then
                        local from = i == 1 and shape.pts[2] or shape.pts[n - 1]
                        cell.char = HEAD_FAMILIES[family][dirBetween(from, tip)]
                    end
                end
            end
        end
    end

    local rows = {}
    for y in pairs(dirty) do
        local cells = {}
        for i, ch in ipairs(modelBackground(base, y)) do cells[i] = ch end
        if clear and y >= clear[2] and y <= clear[4] then
            for x = clear[1], clear[3] do
                if x < #cells then cellsPut(cells, x, ' ') end
            end
        end
        if move then
            if y >= move[2] and y <= move[4] then
                for x = move[1], move[3] do
                    if x < #cells then cellsPut(cells, x, ' ') end
                end
            end
            local source_y = y - move[6]
            if source_y >= move[2] and source_y <= move[4] then
                local source = modelBackground(base, source_y)
                for x = move[1], move[3] do
                    local ch = source[x + 1]
                    if ch == nil then
                        ch = ' '
                    elseif ch == false then
                        -- the rest of a tab moves as spaces, the rest of a wide char came along with its start
                        local first = x + 1
                        while source[first] == false do first = first - 1 end
                        ch = source[first] == '\t' and ' '
                    end
                    if ch and x + move[5] >= 0 then cellsPut(cells, x + move[5], ch) end
                end
            end
        end
        for x, cell in pairs(raster[y] or {}) do
            cellsPut(cells, x, cell.char or CHARS[cell.style][cell.mask])
        end
        rows[y] = cellsString(cells)
    end
    return rows
end

return M
