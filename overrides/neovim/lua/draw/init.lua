-- Draw mode: boxes, lines and arrows drawn into the buffer with the mouse. Nothing is stored next
-- to the text, see draw/model.lua. A line that ends at a box follows it when the box moves.
--
-- press, drag and release take cells so the gestures can be driven without a mouse.
local model = require('draw.model')
local route = require('draw.route')

local M = {}

local ns = vim.api.nvim_create_namespace('draw')
local states = {} -- by buffer

local BAR = {
    { key = 'v', label = 'select', tool = 'select' },
    { key = 'r', label = 'box',    tool = 'box' },
    { key = '-', label = 'line',   tool = 'line' },
    { key = 'a', label = 'arrow',  tool = 'arrow' },
    { key = 't', label = 'text',   tool = 'text' },
    { key = 's', label = 'style',  action = 'style' },
    { key = 'e', label = 'ends',   action = 'ends' },
    { key = 'x', label = 'delete', action = 'delete' },
    { key = 'q', label = 'quit',   action = 'quit' },
}

local function optGet(win, name)
    return vim.api.nvim_get_option_value(name, { scope = 'local', win = win })
end

local function optSet(win, name, value)
    vim.api.nvim_set_option_value(name, value, { scope = 'local', win = win })
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

-- [[ Buffer ]]

local function stateSync(st)
    local tick = vim.api.nvim_buf_get_changedtick(st.buf)
    if not st.model or st.tick ~= tick then
        st.model = model.modelParse(vim.api.nvim_buf_get_lines(st.buf, 0, -1, false), vim.bo[st.buf].tabstop)
        st.tick = tick
    end
    return st.model
end

-- Writes a frame. Every frame of a gesture is rendered from the same base, so the rows an earlier
-- frame touched are put back, and all of it lands in one undo step.
local function frameApply(st, frame)
    local buf, base = st.buf, frame.base
    local rows = model.frameRender(frame)
    local written = {}
    for y in pairs(rows) do written[y] = true end
    for y in pairs(st.written or {}) do
        if rows[y] == nil then rows[y] = base.text[y + 1] or '' end
    end
    st.written = written

    local need = base.nrows
    for y, text in pairs(rows) do
        if text ~= '' then need = math.max(need, y + 1) end
    end
    local function linesSet(first, last, lines)
        if st.joined then pcall(vim.cmd.undojoin) end
        vim.api.nvim_buf_set_lines(buf, first, last, false, lines)
        st.joined = true
    end
    local count = vim.api.nvim_buf_line_count(buf)
    if count > need then
        linesSet(need, count, {})
    elseif count < need then
        local blank = {}
        for i = 1, need - count do blank[i] = '' end
        linesSet(count, count, blank)
    end
    for y, text in pairs(rows) do
        if y < need then
            -- a row that comes out the same apart from trailing blanks keeps them
            local original = base.text[y + 1]
            if original and (original:gsub(' +$', '')) == text then text = original end
            if vim.api.nvim_buf_get_lines(buf, y, y + 1, false)[1] ~= text then linesSet(y, y + 1, { text }) end
        end
    end
end

local function cursorSet(st, x, y)
    y = math.min(y, vim.api.nvim_buf_line_count(st.buf) - 1)
    vim.api.nvim_win_call(st.win, function()
        vim.cmd(('keepjumps normal! %dG%d|'):format(y + 1, x + 1))
    end)
end

-- [[ Selection ]]
-- { shape, key } for one shape, { rect = { x1, y1, x2, y2 } } for a region

local function highlightSet(st, cells, rect)
    local buf = st.buf
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local runs = {} -- { [y] = { { x1, x2 }, ... } }
    if rect then
        for y = rect[2], rect[4] do runs[y] = { { rect[1], rect[3] } } end
    end
    if cells then
        local by_row = {}
        for _, cell in ipairs(cells) do
            by_row[cell[2]] = by_row[cell[2]] or {}
            table.insert(by_row[cell[2]], cell[1])
        end
        for y, xs in pairs(by_row) do
            table.sort(xs)
            runs[y] = {}
            for _, x in ipairs(xs) do
                local last = runs[y][#runs[y]]
                if last and x <= last[2] + 1 then last[2] = x else table.insert(runs[y], { x, x }) end
            end
        end
    end

    local count = vim.api.nvim_buf_line_count(buf)
    local leftcol = vim.fn.getwininfo(st.win)[1].leftcol or 0
    for y, row_runs in pairs(runs) do
        if y >= 0 and y < count then
            local line = vim.api.nvim_buf_get_lines(buf, y, y + 1, false)[1]
            local cells_y = model.lineCells(line, vim.bo[buf].tabstop)
            for _, run in ipairs(row_runs) do
                local first = model.cellsByte(cells_y, run[1])
                if first then
                    vim.api.nvim_buf_set_extmark(buf, ns, y, first, {
                        end_col = model.cellsByte(cells_y, run[2] + 1) or #line, hl_group = 'DrawSelect', priority = 200,
                    })
                end
                -- the part past the end of the line has no text to highlight
                local from = math.max(run[1], #cells_y)
                if run[2] >= from and from - leftcol >= 0 then
                    vim.api.nvim_buf_set_extmark(buf, ns, y, 0, {
                        virt_text = { { (' '):rep(run[2] - from + 1), 'DrawSelect' } },
                        virt_text_win_col = from - leftcol,
                    })
                end
            end
        end
    end
end

local function selSet(st, shape, rect)
    if shape then
        st.sel = { shape = model.shapeCopy(shape), key = model.shapeKey(shape, true) }
        highlightSet(st, model.shapeCells(shape), nil)
    else
        st.sel = rect and { rect = rect } or nil
        highlightSet(st, nil, rect)
    end
end

-- The indices of the selected shapes in the current model. A selected shape that is no longer in
-- the text drops the selection.
local function selIndices(st)
    local sel = st.sel
    if not sel then return {} end
    local indices = {}
    for i, shape in ipairs(stateSync(st).shapes) do
        if sel.rect then
            local x1, y1, x2, y2 = model.shapeBounds(shape)
            if x1 >= sel.rect[1] and y1 >= sel.rect[2] and x2 <= sel.rect[3] and y2 <= sel.rect[4] then
                indices[#indices + 1] = i
            end
        elseif model.shapeKey(shape, true) == sel.key then
            return { i }
        end
    end
    if not sel.rect then selSet(st, nil) end
    return indices
end

-- [[ Geometry ]]

local function boxContains(box, x, y)
    return x >= box.x and x < box.x + box.w and y >= box.y and y < box.y + box.h
end

local function lineContains(line, x, y)
    for i = 1, #line.pts - 1 do
        local a, b = line.pts[i], line.pts[i + 1]
        if x >= math.min(a[1], b[1]) and x <= math.max(a[1], b[1])
            and y >= math.min(a[2], b[2]) and y <= math.max(a[2], b[2]) then
            return true
        end
    end
    return false
end

-- The smallest box that contains a cell, and its index.
local function boxInnermost(shapes, x, y)
    local found, found_i
    for i, shape in ipairs(shapes) do
        if shape.kind == 'box' and boxContains(shape, x, y) and (not found or shape.w * shape.h < found.w * found.h) then
            found, found_i = shape, i
        end
    end
    return found, found_i
end

-- An anchor on one side of a box for a line whose other end is at other.
local function anchorOnSide(box, side, other)
    local horizontal = side == 'l' or side == 'r'
    local length = horizontal and box.h or box.w
    local toward = horizontal and other[2] - box.y or other[1] - box.x
    -- straight across from the other end when that isn't a corner, the middle of the side otherwise
    local off = math.floor((length - 1) / 2)
    if length <= 2 then
        off = clamp(toward, 0, length - 1)
    elseif toward >= 1 and toward <= length - 2 then
        off = toward
    end
    return { box = box, side = side, off = off, on = false }
end

-- The anchor for a line end dropped on cell, with the line's other end at other. A cell on a side
-- of the box takes that spot and is pinned to it, a cell inside the box or on a corner takes the
-- side that faces the other end. No anchor when the other end is inside the same box.
local function anchorPick(shapes, cell, other)
    local box = boxInnermost(shapes, cell[1], cell[2])
    if not box or boxContains(box, other[1], other[2]) then return false end
    local x2, y2 = box.x + box.w - 1, box.y + box.h - 1
    local on_l, on_r, on_t, on_b = cell[1] == box.x, cell[1] == x2, cell[2] == box.y, cell[2] == y2
    if not ((on_l or on_r) and (on_t or on_b)) then
        local side = on_l and 'l' or on_r and 'r' or on_t and 't' or on_b and 'b'
        if side then
            local off = (on_l or on_r) and cell[2] - box.y or cell[1] - box.x
            return { box = box, side = side, off = off, on = false, pinned = true }
        end
    end
    local in_rows = other[2] >= box.y and other[2] <= y2
    local in_cols = other[1] >= box.x and other[1] <= x2
    local dx, dy = other[1] - (box.x + x2) / 2, other[2] - (box.y + y2) / 2
    local horizontal = in_rows
    if in_rows == in_cols then horizontal = math.abs(dx) / box.w >= math.abs(dy) / box.h end
    if horizontal then return anchorOnSide(box, dx >= 0 and 'r' or 'l', other) end
    return anchorOnSide(box, dy >= 0 and 'b' or 't', other)
end

-- What it costs a line to leave the side it was attached to, in the router's score. A bend is 10,
-- so an end only changes sides when that saves two bends or keeps the line out of a box.
local SIDE_SWITCH_COST = 15

-- Routes a line again from its ends. A free end stays where it is. An anchored end leaves its box
-- straight, and moves to another side of it when the route from there is that much better, unless
-- the anchor is pinned. shapes are the boxes to stay out of.
local function lineReroute(line, shapes, prefer_h)
    local n = #line.pts
    if prefer_h == nil and n >= 2 then prefer_h = line.pts[1][2] == line.pts[2][2] end

    local avoid = {}
    for _, shape in ipairs(shapes) do
        if shape.kind == 'box' then
            local x1, y1, x2, y2 = model.shapeBounds(shape)
            local near = (line.anchor[1] and line.anchor[1].box == shape) or (line.anchor[2] and line.anchor[2].box == shape)
            avoid[#avoid + 1] = { x1, y1, x2, y2, near = near or false }
        end
    end

    -- The ways an end can be placed, each { anchor, point, normal, cost }: on the anchor it has or
    -- on another side of the same box. A spot with no room for the line next to the box is out.
    local function endOptions(i, other)
        local current = line.anchor[i]
        if not current then return { { false, line.pts[i == 1 and 1 or n], nil, 0 } } end
        local options = {}
        local function optionAdd(anchor, cost)
            local p, normal = model.anchorPoint(anchor)
            if p[1] >= 0 and p[2] >= 0 then options[#options + 1] = { anchor, p, normal, cost } end
        end
        optionAdd(current, 0)
        -- a pinned anchor only gives up its side when the line doesn't fit there
        if not current.pinned or #options == 0 then
            for _, side in ipairs({ 'l', 'r', 't', 'b' }) do
                if side ~= current.side then optionAdd(anchorOnSide(current.box, side, other), SIDE_SWITCH_COST) end
            end
        end
        return options
    end

    -- the first end is placed against where the second one is now, the second against the first
    local second = line.anchor[2] and model.anchorPoint(line.anchor[2]) or line.pts[n]
    local best
    for _, first in ipairs(endOptions(1, second)) do
        for _, last in ipairs(endOptions(2, first[2])) do
            local arrive = last[3] and { -last[3][1], -last[3][2] }
            local pts, score = route.route(first[2], first[3], last[2], arrive, prefer_h, avoid)
            score = score + first[4] + last[4]
            if not best or score < best.score then
                best = { pts = pts, score = score, anchors = { first[1], last[1] } }
            end
        end
    end
    line.pts, line.anchor = best.pts, best.anchors
end

-- A frame with the picked shape, or everything inside rect along with its background, moved. Lines
-- attached to a moved box are routed again. Also returns the offset after keeping it on the canvas.
local function frameMove(base, rect, picked, dx, dy)
    local frame, copies = model.modelFork(base)
    local moved = {}
    local min_x, min_y = rect and rect[1] or math.huge, rect and rect[2] or math.huge
    for i, shape in ipairs(base.shapes) do
        local x1, y1, x2, y2 = model.shapeBounds(shape)
        if shape == picked or (rect and x1 >= rect[1] and y1 >= rect[2] and x2 <= rect[3] and y2 <= rect[4]) then
            moved[copies[i]] = true
            min_x, min_y = math.min(min_x, x1), math.min(min_y, y1)
        end
    end
    dx, dy = math.max(dx, -min_x), math.max(dy, -min_y)
    if dx == 0 and dy == 0 then return frame, 0, 0 end

    for copy in pairs(moved) do model.shapeTranslate(copy, dx, dy) end
    if rect then frame.bgmove = { rect[1], rect[2], rect[3], rect[4], dx, dy } end
    for _, copy in ipairs(copies) do
        if copy.kind == 'line' and not moved[copy] then
            local first = copy.anchor[1] and moved[copy.anchor[1].box]
            local second = copy.anchor[2] and moved[copy.anchor[2].box]
            if first and second then
                model.shapeTranslate(copy, dx, dy)
            elseif first or second then
                lineReroute(copy, frame.shapes)
            end
        end
    end
    return frame, dx, dy
end

-- [[ Gestures ]]
-- A gesture runs from press to release. Its frames are all computed from the model at the press.

local function selectPress(st, g, x, y)
    local shapes = g.base.shapes
    local region = st.sel and st.sel.rect
    if region and x >= region[1] and x <= region[3] and y >= region[2] and y <= region[4] then
        g.kind, g.rect, g.region = 'move', region, true
        return
    end
    -- line ends first, they sit right next to the box borders
    for i, shape in ipairs(shapes) do
        if shape.kind == 'line' then
            for tip, p in ipairs({ shape.pts[1], shape.pts[#shape.pts] }) do
                if p[1] == x and p[2] == y then
                    g.kind, g.shape, g.index, g.tip = 'end', shape, i, tip
                    return
                end
            end
        end
    end
    for i, shape in ipairs(shapes) do
        if shape.kind == 'line' and lineContains(shape, x, y) then
            g.kind, g.shape, g.index = 'move', shape, i
            return
        end
    end
    local box, box_i = boxInnermost(shapes, x, y)
    if box then
        local x1, y1, x2, y2 = model.shapeBounds(box)
        g.shape, g.index = box, box_i
        if (x == x1 or x == x2) and (y == y1 or y == y2) then
            -- a corner resizes against the opposite one
            g.kind, g.fixed = 'resize', { x == x1 and x2 or x1, y == y1 and y2 or y1 }
        else
            g.kind, g.rect = 'move', { x1, y1, x2, y2 }
        end
        return
    end
    g.kind = 'band'
end

-- The frame for the pointer at x, y. Leaves what the gesture produced in g.result_shape or g.result_rect.
local function gestureFrame(st, g, x, y)
    g.result_shape, g.result_rect = nil, nil

    if g.kind == 'box' then
        local frame = model.modelFork(g.base)
        local x1, y1, x2, y2 = math.min(g.x0, x), math.min(g.y0, y), math.max(g.x0, x), math.max(g.y0, y)
        if x2 > x1 and y2 > y1 then
            g.result_shape = { kind = 'box', x = x1, y = y1, w = x2 - x1 + 1, h = y2 - y1 + 1, style = st.style }
            table.insert(frame.shapes, g.result_shape)
        end
        return frame
    end

    if g.kind == 'line' then
        local frame = model.modelFork(g.base)
        if g.prefer_h == nil then g.prefer_h = math.abs(x - g.x0) >= math.abs(y - g.y0) end
        local line = {
            kind = 'line', pts = { { g.x0, g.y0 }, { x, y } }, style = st.style,
            head = { false, g.head }, anchor = { false, false },
        }
        line.anchor[1] = anchorPick(frame.shapes, line.pts[1], line.pts[2])
        -- the far end lines up with where the near end actually starts
        local from = line.anchor[1] and model.anchorPoint(line.anchor[1]) or line.pts[1]
        line.anchor[2] = anchorPick(frame.shapes, line.pts[2], from)
        lineReroute(line, frame.shapes, g.prefer_h)
        if #line.pts >= 2 then
            g.result_shape = line
            table.insert(frame.shapes, line)
        end
        return frame
    end

    if g.kind == 'end' then
        local frame, copies = model.modelFork(g.base)
        local line = copies[g.index]
        local n = #line.pts
        local other = line.pts[g.tip == 1 and n or 1]
        line.pts[g.tip == 1 and 1 or n] = { x, y }
        line.anchor[g.tip] = anchorPick(frame.shapes, { x, y }, other)
        lineReroute(line, frame.shapes, g.shape.pts[1][2] == g.shape.pts[2][2])
        if #line.pts < 2 then
            line = model.shapeCopy(g.shape)
            frame.shapes[g.index] = line
        end
        g.result_shape = line
        return frame
    end

    if g.kind == 'move' then
        local frame, dx, dy = frameMove(g.base, g.rect, g.shape, x - g.x0, y - g.y0)
        if g.region then
            g.result_rect = { g.rect[1] + dx, g.rect[2] + dy, g.rect[3] + dx, g.rect[4] + dy }
        else
            g.result_shape = frame.shapes[g.index]
        end
        return frame
    end

    -- resize
    local frame, copies = model.modelFork(g.base)
    local box = copies[g.index]
    local x1, y1, x2, y2 = math.min(g.fixed[1], x), math.min(g.fixed[2], y), math.max(g.fixed[1], x), math.max(g.fixed[2], y)
    if x2 == x1 then x2 = x1 + 1 end
    if y2 == y1 then y2 = y1 + 1 end
    box.x, box.y, box.w, box.h = x1, y1, x2 - x1 + 1, y2 - y1 + 1
    if model.shapeKey(box) ~= model.shapeKey(g.shape) then
        for _, copy in ipairs(copies) do
            if copy.kind == 'line' then
                local first, second = copy.anchor[1], copy.anchor[2]
                if (first and first.box == box) or (second and second.box == box) then lineReroute(copy, frame.shapes) end
            end
        end
    end
    g.result_shape = box
    return frame
end

-- Puts the cursor on a cell, adding the lines it takes to get there.
local function textCursor(st, x, y)
    local count = vim.api.nvim_buf_line_count(st.buf)
    if y >= count then
        local blank = {}
        for i = 1, y - count + 1 do blank[i] = '' end
        vim.api.nvim_buf_set_lines(st.buf, count, count, false, blank)
    end
    cursorSet(st, x, y)
end

local function textStart(st, x, y)
    selSet(st, nil)
    textCursor(st, x, y)
    -- replace mode, so typing into a box doesn't push its border
    vim.cmd('startreplace')
end

function M.press(buf, x, y)
    local st = states[buf]
    if not st then return end
    st.gesture, st.written, st.joined = nil, nil, false
    if st.tool == 'text' then
        textStart(st, x, y)
        return
    end
    local g = { x0 = x, y0 = y, x = x, y = y, base = stateSync(st) }
    if st.tool == 'box' then
        g.kind = 'box'
        selSet(st, nil)
    elseif st.tool == 'line' or st.tool == 'arrow' then
        g.kind, g.head = 'line', st.tool == 'arrow' and 1
        selSet(st, nil)
    else
        selectPress(st, g, x, y)
        if not g.region then selSet(st, g.shape) end
    end
    st.gesture = g
end

function M.drag(buf, x, y)
    local st = states[buf]
    local g = st and st.gesture
    if not g or (x == g.x and y == g.y) then return end
    g.x, g.y = x, y
    if g.kind == 'band' then
        selSet(st, nil, { math.min(g.x0, x), math.min(g.y0, y), math.max(g.x0, x), math.max(g.y0, y) })
        return
    end
    frameApply(st, gestureFrame(st, g, x, y))
    selSet(st, g.result_shape, g.result_rect)
end

function M.release(buf)
    local st = states[buf]
    if not st or not st.gesture then return end
    st.gesture = nil
    if st.joined then
        st.model = nil
        -- a shape that didn't come back out of the text the way it went in isn't selected
        selIndices(st)
    end
end

-- [[ Actions ]]

local barUpdate

-- Applies fn to a copy of every selected shape as one undo step.
local function selEdit(st, fn)
    local indices = selIndices(st)
    if #indices == 0 then return false end
    local frame, copies = model.modelFork(stateSync(st))
    local single = not st.sel.rect and copies[indices[1]]
    for _, i in ipairs(indices) do fn(copies[i]) end
    st.written, st.joined = nil, false
    frameApply(st, frame)
    st.model = nil
    if single then selSet(st, single) else selSet(st, nil, st.sel.rect) end
    return true
end

local function styleCycle(st)
    local function styleNext(style)
        for i, name in ipairs(model.STYLES) do
            if name == style then return model.STYLES[i % #model.STYLES + 1] end
        end
        return model.STYLES[1]
    end
    -- without a selection it is the style of what gets drawn next
    if not selEdit(st, function(shape)
        shape.style = styleNext(shape.style)
        st.style = shape.style
    end) then
        st.style = styleNext(st.style)
    end
    barUpdate(st)
end

-- none, end, both, start
local function endsCycle(st)
    selEdit(st, function(shape)
        if shape.kind ~= 'line' then return end
        local family = shape.head[1] or shape.head[2] or 1
        local first, second = shape.head[1], shape.head[2]
        if not first and not second then
            shape.head = { false, family }
        elseif not first then
            shape.head = { family, family }
        elseif second then
            shape.head = { family, false }
        else
            shape.head = { false, false }
        end
    end)
end

local function selDelete(st)
    local sel = st.sel
    local indices = selIndices(st)
    if not sel or (#indices == 0 and not sel.rect) then
        -- nothing selected: the char under the cursor, as usual
        vim.cmd('normal! x')
        return
    end
    local base = stateSync(st)
    local frame, copies = model.modelFork(base)
    -- a box goes with what is inside it
    local rect = sel.rect
    local picked = not rect and base.shapes[indices[1]]
    if picked and picked.kind == 'box' then rect = { model.shapeBounds(picked) } end
    frame.shapes = {}
    for i, shape in ipairs(base.shapes) do
        local x1, y1, x2, y2 = model.shapeBounds(shape)
        local inside = rect and x1 >= rect[1] and y1 >= rect[2] and x2 <= rect[3] and y2 <= rect[4]
        if shape ~= picked and not inside then table.insert(frame.shapes, copies[i]) end
    end
    frame.bgclear = rect
    st.written, st.joined = nil, false
    frameApply(st, frame)
    st.model = nil
    selSet(st, nil)
end

local function toolSet(st, tool)
    st.tool = tool
    if tool ~= 'select' then selSet(st, nil) end
    barUpdate(st)
end

local function actionRun(st, item)
    if item.tool then
        toolSet(st, item.tool)
    elseif item.action == 'style' then
        styleCycle(st)
    elseif item.action == 'ends' then
        endsCycle(st)
    elseif item.action == 'delete' then
        selDelete(st)
    else
        M.stop(st.buf)
    end
end

-- [[ Bar ]]
-- The winbar lists the tools. It is clicked through the same mouse mapping as the canvas, so the
-- columns of every entry are kept.

barUpdate = function(st)
    -- a bar wider than the window gets cut off on the left and the columns stop matching, so a
    -- narrow window only gets the keys
    local parts, spans, col
    for _, with_labels in ipairs({ true, false }) do
        parts, spans, col = { '%#DrawBar#' }, {}, 0
        for _, item in ipairs(BAR) do
            local text = (' %s '):format(item.key)
            if with_labels then
                text = (' %s %s '):format(item.key, item.action == 'style' and st.style or item.label)
            end
            parts[#parts + 1] = ('%%#%s#%s'):format(item.tool == st.tool and 'DrawBarActive' or 'DrawBar', text)
            spans[#spans + 1] = { col + 1, col + #text, item }
            col = col + #text
        end
        if col <= vim.api.nvim_win_get_width(st.win) then break end
    end
    parts[#parts + 1] = '%#DrawBar#'
    st.bar_spans = spans
    optSet(st.win, 'winbar', table.concat(parts))
end

-- [[ Mouse ]]

-- The cell under the mouse, or nil and the window column when it is on the winbar.
local function mouseCell(st)
    local mouse = vim.fn.getmousepos()
    if mouse.winid ~= st.win then return nil end
    local info = vim.fn.getwininfo(st.win)[1]
    if mouse.winrow <= info.winbar then return nil, mouse.wincol end
    local x = math.max(mouse.wincol - 1 - info.textoff, 0) + (info.leftcol or 0)
    local y = info.topline - 1 + (mouse.winrow - 1 - info.winbar)
    return { x, y }
end

local function mouseHandle(kind)
    return function()
        local buf = vim.api.nvim_get_current_buf()
        local st = states[buf]
        local cell, bar_col
        if st and vim.api.nvim_get_current_win() == st.win then cell, bar_col = mouseCell(st) end
        if kind == 'release' then
            M.release(buf)
        elseif kind == 'drag' then
            if cell then
                M.drag(buf, cell[1], cell[2])
                cursorSet(st, cell[1], cell[2])
            end
        elseif bar_col then
            for _, span in ipairs(st.bar_spans) do
                if bar_col >= span[1] and bar_col <= span[2] then actionRun(st, span[3]) end
            end
        elseif not cell then
            -- another window: the click does what it would have done
            vim.api.nvim_feedkeys(vim.keycode('<LeftMouse>'), 'n', false)
        elseif kind == 'text' then
            st.gesture = nil
            textStart(st, cell[1], cell[2])
        else
            cursorSet(st, cell[1], cell[2])
            M.press(buf, cell[1], cell[2])
        end
    end
end

-- [[ Mode ]]

function M.active(buf)
    return states[buf or vim.api.nvim_get_current_buf()] ~= nil
end

function M.toolSet(buf, tool)
    if states[buf] then toolSet(states[buf], tool) end
end

function M.start()
    local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
    if states[buf] then return end
    if not vim.bo[buf].modifiable then
        vim.notify('draw: buffer is not modifiable', vim.log.levels.WARN)
        return
    end
    local st = { buf = buf, win = win, tool = 'select', style = 'light', saved_opts = {}, saved_maps = {} }
    states[buf] = st

    vim.api.nvim_set_hl(0, 'DrawSelect', { default = true, link = 'Visual' })
    vim.api.nvim_set_hl(0, 'DrawBar', { default = true, link = 'WinBar' })
    vim.api.nvim_set_hl(0, 'DrawBarActive', { default = true, link = 'CurSearch' })

    -- the canvas: the cursor goes anywhere, a row is a line, no whitespace markers, nothing hidden
    for name, value in pairs({ virtualedit = 'all', wrap = false, list = false, foldenable = false, winbar = '' }) do
        st.saved_opts[name] = optGet(win, name)
        optSet(win, name, value)
    end
    -- completion popups and indent guides get in the way of drawing
    st.saved_completion = vim.b[buf].completion
    vim.b[buf].completion = false
    pcall(function() require('ibl').setup_buffer(buf, { enabled = false }) end)

    local maps = {
        { 'n', '<LeftMouse>',   mouseHandle('press') },
        { 'n', '<2-LeftMouse>', mouseHandle('text') },
        { 'n', '<3-LeftMouse>', mouseHandle('press') },
        { 'n', '<4-LeftMouse>', mouseHandle('press') },
        { 'n', '<LeftDrag>',    mouseHandle('drag') },
        { 'n', '<LeftRelease>', mouseHandle('release') },
        { 'n', '<Del>',         function() selDelete(st) end },
        { 'n', '<Esc>',         function() toolSet(st, 'select'); selSet(st, nil) end },
        -- a line break would shift everything below, the text goes on underneath where it started
        { 'i', '<CR>', function() textCursor(st, st.text_x or 0, vim.fn.line('.')) end },
    }
    for _, item in ipairs(BAR) do
        table.insert(maps, { 'n', item.key, function() actionRun(st, item) end })
    end
    for _, map in ipairs(maps) do
        local previous = vim.fn.maparg(map[2], map[1], false, true)
        if previous.buffer == 1 then table.insert(st.saved_maps, previous) end
        vim.keymap.set(map[1], map[2], map[3], { buffer = buf, nowait = true, silent = true, desc = 'Draw mode' })
    end
    st.maps = maps

    st.augroup = vim.api.nvim_create_augroup('draw' .. buf, {})
    vim.api.nvim_create_autocmd('BufWinLeave', { group = st.augroup, buffer = buf, callback = function() M.stop(buf) end })
    vim.api.nvim_create_autocmd('WinClosed', { group = st.augroup, pattern = tostring(win), callback = function() M.stop(buf) end })
    vim.api.nvim_create_autocmd('WinResized', { group = st.augroup, callback = function() barUpdate(st) end })
    vim.api.nvim_create_autocmd('InsertEnter', {
        group = st.augroup, buffer = buf,
        callback = function() st.text_x = vim.fn.virtcol('.') - 1 end,
    })
    vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
        group = st.augroup, buffer = buf,
        callback = function()
            -- an undo or an edit can take the selected shape away
            if st.sel and not st.gesture then selIndices(st) end
        end,
    })

    barUpdate(st)
end

function M.stop(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local st = states[buf]
    if not st then return end
    states[buf] = nil
    vim.api.nvim_del_augroup_by_id(st.augroup)
    if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        for _, map in ipairs(st.maps) do pcall(vim.keymap.del, map[1], map[2], { buffer = buf }) end
        for _, previous in ipairs(st.saved_maps) do
            vim.api.nvim_buf_call(buf, function() vim.fn.mapset(previous) end)
        end
        vim.b[buf].completion = st.saved_completion
        pcall(function() require('ibl').setup_buffer(buf, { enabled = true }) end)
    end
    if vim.api.nvim_win_is_valid(st.win) then
        for name, value in pairs(st.saved_opts) do optSet(st.win, name, value) end
    end
end

function M.toggle()
    if M.active() then M.stop() else M.start() end
end

return M
