-- Orthogonal routing between two cells. Points are { x, y }, directions are { dx, dy } unit vectors.
local M = {}

local function sign(v)
    if v > 0 then return 1 elseif v < 0 then return -1 end
    return 0
end

-- Drops repeated points and the middle of collinear runs. nil when a segment is diagonal or doubles back.
local function pointsSimplify(pts)
    local out = {}
    for _, p in ipairs(pts) do
        local n = #out
        if n == 0 or out[n][1] ~= p[1] or out[n][2] ~= p[2] then
            if n >= 1 and out[n][1] ~= p[1] and out[n][2] ~= p[2] then return nil end
            if n >= 2 then
                local a, b = out[n - 1], out[n]
                local d1x, d1y = sign(b[1] - a[1]), sign(b[2] - a[2])
                local d2x, d2y = sign(p[1] - b[1]), sign(p[2] - b[2])
                if d1x == d2x and d1y == d2y then
                    out[n] = nil
                elseif d1x == -d2x and d1y == -d2y then
                    return nil
                end
            end
            out[#out + 1] = { p[1], p[2] }
        end
    end
    return out
end

-- Path cells that fall into one of the rects, the two end cells don't count.
local function pointsCrossings(pts, avoid)
    local count = 0
    for i = 1, #pts - 1 do
        local a, b = pts[i], pts[i + 1]
        local dx, dy = sign(b[1] - a[1]), sign(b[2] - a[2])
        local x, y = a[1], a[2]
        while true do
            local is_end = (i == 1 and x == a[1] and y == a[2]) or (i == #pts - 1 and x == b[1] and y == b[2])
            if not is_end then
                for _, r in ipairs(avoid) do
                    if x >= r[1] and x <= r[3] and y >= r[2] and y <= r[4] then
                        count = count + 1
                        break
                    end
                end
            end
            if x == b[1] and y == b[2] then break end
            x, y = x + dx, y + dy
        end
    end
    return count
end

-- Routes from a to b. da is the direction the first segment has to leave a in, db the direction the
-- last segment has to arrive at b in, either can be nil. prefer_h breaks ties toward a horizontal
-- first segment. avoid is a list of { x1, y1, x2, y2, near = bool } rects the path should stay out
-- of, near marks the ones the line is attached to. Also returns the score of the path, lower is better.
function M.route(a, da, b, db, prefer_h, avoid)
    avoid = avoid or {}
    if a[1] == b[1] and a[2] == b[2] then return { { a[1], a[2] } }, 0 end

    local a_stub = da and { a[1] + da[1], a[2] + da[2] }
    local b_stub = db and { b[1] - db[1], b[2] - db[2] }

    -- detour lanes: just outside the ends and what they are attached to, and outside everything
    local lanes_x, lanes_y = {}, {}
    do
        local x1, y1 = math.min(a[1], b[1]), math.min(a[2], b[2])
        local x2, y2 = math.max(a[1], b[1]), math.max(a[2], b[2])
        for _, p in ipairs({ a_stub or a, b_stub or b }) do
            x1, y1, x2, y2 = math.min(x1, p[1]), math.min(y1, p[2]), math.max(x2, p[1]), math.max(y2, p[2])
        end
        for _, near in ipairs({ true, false }) do
            for _, r in ipairs(avoid) do
                if not near or r.near then
                    x1, y1, x2, y2 = math.min(x1, r[1]), math.min(y1, r[2]), math.max(x2, r[3]), math.max(y2, r[4])
                end
            end
            lanes_x[#lanes_x + 1], lanes_x[#lanes_x + 2] = x1 - 1, x2 + 1
            lanes_y[#lanes_y + 1], lanes_y[#lanes_y + 2] = y1 - 1, y2 + 1
        end
    end

    local function innerRoutes(p, q)
        local mx = math.floor((p[1] + q[1]) / 2 + 0.5)
        local my = math.floor((p[2] + q[2]) / 2 + 0.5)
        -- the first of equally good routes wins: a bend halfway looks better than one right at a box
        local routes = {
            { p, q },
            { p, { mx, p[2] }, { mx, q[2] }, q },
            { p, { p[1], my }, { q[1], my }, q },
            { p, { q[1], p[2] }, q },
            { p, { p[1], q[2] }, q },
        }
        for _, lane_x in ipairs(lanes_x) do
            routes[#routes + 1] = { p, { lane_x, p[2] }, { lane_x, q[2] }, q }
        end
        for _, lane_y in ipairs(lanes_y) do
            routes[#routes + 1] = { p, { p[1], lane_y }, { q[1], lane_y }, q }
        end
        return routes
    end

    local best, best_score
    local function candidateAdd(raw)
        local pts = pointsSimplify(raw)
        if not pts or #pts < 2 then return end
        for _, p in ipairs(pts) do
            if p[1] < 0 or p[2] < 0 then return end
        end
        local n = #pts
        local first_dx, first_dy = sign(pts[2][1] - pts[1][1]), sign(pts[2][2] - pts[1][2])
        if da and (first_dx ~= da[1] or first_dy ~= da[2]) then return end
        if db and (sign(pts[n][1] - pts[n - 1][1]) ~= db[1] or sign(pts[n][2] - pts[n - 1][2]) ~= db[2]) then return end
        local length = 0
        for i = 1, n - 1 do
            length = length + math.abs(pts[i + 1][1] - pts[i][1]) + math.abs(pts[i + 1][2] - pts[i][2])
        end
        local score = (n - 2) * 10 + length + pointsCrossings(pts, avoid) * 100
        if prefer_h ~= nil and (first_dy == 0) ~= prefer_h then score = score + 1 end
        if not best_score or score < best_score then best, best_score = pts, score end
    end

    for _, inner in ipairs(innerRoutes(a_stub or a, b_stub or b)) do
        local raw = {}
        if a_stub then raw[#raw + 1] = a end
        for _, p in ipairs(inner) do raw[#raw + 1] = p end
        if b_stub then raw[#raw + 1] = b end
        candidateAdd(raw)
    end

    if best then return best, best_score end
    return pointsSimplify({ a, { b[1], a[2] }, b }) or { { a[1], a[2] }, { b[1], b[2] } }, math.huge
end

return M
