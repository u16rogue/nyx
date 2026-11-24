local mainMod = "SUPER"

local function resolvePathCommand(name)
    return '"$(PATH="${NYX_HYPR_PATH:+$NYX_HYPR_PATH:}$PATH" command -v ' .. name .. ')"'
end

hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.on("hyprland.start", function()
    hl.exec_cmd(resolvePathCommand("hyprpaper"))
    hl.exec_cmd(resolvePathCommand("waybar"))
    hl.exec_cmd(resolvePathCommand("mako"))
end)

hl.bind(mainMod .. " + SHIFT + X", hl.dsp.exec_cmd(resolvePathCommand("uwsm") .. " stop"))
hl.bind(mainMod .. " + TAB", hl.dsp.group.toggle())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.kill())
hl.bind(mainMod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }))
-- Sway's sticky: a floating window that stays on screen across workspaces (picture in picture).
hl.bind(mainMod .. " + ALT + SPACE", hl.dsp.window.pin({ action = "toggle" }))
-- Sway's focus mode_toggle: jump between the floating and the tiled windows.
hl.bind(mainMod .. " + SPACE", function()
    local window = hl.get_active_window()
    if window and window.floating then
        return hl.dispatch(hl.dsp.window.cycle_next({ tiled = true }))
    end
    return hl.dispatch(hl.dsp.window.cycle_next({ floating = true }))
end)

hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    local function bindResize(key, x, y)
        hl.bind(key, hl.dsp.window.resize({ x = x, y = y, relative = true }), { repeating = true })
    end
    -- WASD in steps of 10, the arrows for single pixels.
    for step, keys in pairs({ [10] = { "A", "D", "W", "S" }, [1] = { "left", "right", "up", "down" } }) do
        bindResize(keys[1], -step, 0)
        bindResize(keys[2], step, 0)
        bindResize(keys[3], 0, -step)
        bindResize(keys[4], 0, step)
    end
    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("Escape", hl.dsp.submap("reset"))
end)

hl.bind(mainMod .. " + SHIFT + GRAVE", hl.dsp.exec_cmd(resolvePathCommand("ghostty")))
hl.bind(mainMod .. " + GRAVE", hl.dsp.exec_cmd(resolvePathCommand("fuzzel")))
hl.bind(mainMod .. " + F1", hl.dsp.dpms({ action = "toggle" }))
hl.bind("CTRL + PRINT", function()
    local monitor = hl.get_monitor_at_cursor()
    local output = monitor and string.format("-o '%s'", monitor.name) or ""
    return hl.dispatch(hl.dsp.exec_cmd(string.format(
        [=[%s %s -t ppm - | %s -f - -o - --initial-tool crop --actions-on-enter save-to-file --early-exit | %s]=],
        resolvePathCommand("grim"), output, resolvePathCommand("satty"), resolvePathCommand("wl-copy")
    )))
end)

-- Sway's focus_wrapping workspace. Hyprland wraps to the window at the opposite edge by itself once
-- window_direction_monitor_fallback is off, but it only wraps the tabs of a group on a single monitor setup.
local function focusDirection(direction)
    local before = hl.get_active_window()
    local result = hl.dispatch(hl.dsp.focus({ direction = direction }))
    local after = hl.get_active_window()
    local stuck = before and after and before.address == after.address
    if not stuck or not after.group or after.group.size < 2 then
        return result
    end
    if direction == "l" then
        return hl.dispatch(hl.dsp.group.prev())
    elseif direction == "r" then
        return hl.dispatch(hl.dsp.group.next())
    end
    return result
end

for key, direction in pairs({ A = "l", D = "r", W = "u", S = "d" }) do
    hl.bind(mainMod .. " + " .. key, function() return focusDirection(direction) end)
end

-- Waybar starts hidden: toggle on modifier press, then toggle back on release.
-- Uses the raw key event rather than binds: since 0.57 a `SUPER + SUPER_L` release bind
-- doesn't match while another key is still held (e.g. releasing Super before 1 on a quick Super+1).
local SUPER_L_KEYCODE = 133 -- xkb keycode (evdev KEY_LEFTMETA 125 + 8)
hl.on("input.keyboard.key", function(keycode)
    if keycode == SUPER_L_KEYCODE then
        hl.dispatch(hl.dsp.exec_cmd(resolvePathCommand("pkill") .. " -SIGUSR1 waybar"))
    end
end)

-- Sway-like tab movement without moving the whole Hyprland group.
local function moveWindow(direction)
    local window = hl.get_active_window()
    if not window or window.fullscreen ~= 0 then
        return
    end
    local group = window.group
    if group then
        if direction == "l" and group.current_index > 1 then
            return hl.dispatch(hl.dsp.group.move_window({ forward = false }))
        elseif direction == "r" and group.current_index < group.size then
            return hl.dispatch(hl.dsp.group.move_window({ forward = true }))
        end
        -- At a tab edge (or vertically), detach only this window in that direction.
        local single = group.size == 1
        local result = hl.dispatch(hl.dsp.window.move({ out_of_group = direction, window = window }))
        if not result.ok or not single then return result end
        -- Removing a one-tab group only drops its container; still perform the requested move.
    end
    return hl.dispatch(hl.dsp.window.move({ direction = direction, group_aware = true }))
end

for key, direction in pairs({ A = "l", D = "r", W = "u", S = "d" }) do
    hl.bind(mainMod .. " + SHIFT + " .. key, function() return moveWindow(direction) end)
end

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, function()
        local window = hl.get_active_window()
        if not window or (window.workspace and window.workspace.id == i) then
            return
        end
        -- Workspace moves otherwise carry every tab; detach first and keep this workspace visible.
        if window.group then
            local result = hl.dispatch(hl.dsp.window.move({ out_of_group = true, window = window }))
            if not result.ok then return result end
        end
        return hl.dispatch(hl.dsp.window.move({ workspace = i, window = window, follow = false }))
    end)
end

local function fullscreenSafeMouse(dispatcher)
    local started = false
    return function()
        -- Always finish a started drag, even if fullscreen/focus changed before release.
        if started then
            started = false
            return hl.dispatch(dispatcher)
        end
        local monitor = hl.get_monitor_at_cursor()
        local workspace = monitor and (monitor.active_special_workspace or monitor.active_workspace)
        if workspace and workspace.has_fullscreen then
            return { pass_event = true }
        end
        started = true
        return hl.dispatch(dispatcher)
    end
end

-- Test the pointer's workspace, not keyboard focus: follow_mouse is disabled.
hl.bind(mainMod .. " + mouse:272", fullscreenSafeMouse(hl.dsp.window.drag()))
hl.bind(mainMod .. " + mouse:273", fullscreenSafeMouse(hl.dsp.window.resize()))

hl.config({
    general = {
        gaps_in = 0,
        gaps_out = 0,
        border_size = 2,
        col = {
            active_border = "rgb(d2e1fa)",
            inactive_border = "rgb(6d7b91)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },
    animations = {
        enabled = false,
    },
    dwindle = {
        smart_split = true,
        preserve_split = true,
    },
    group = {
        focus_removed_window = true,
        group_on_movetoworkspace = false,
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
    input = {
        kb_layout = "us",
        numlock_by_default = true,
        follow_mouse = 0,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
    binds = {
        movefocus_cycles_groupfirst = true,
        -- Directional focus never leaves the monitor, the other one is reached by its workspaces.
        window_direction_monitor_fallback = false,
    },
})

hl.permission({
    binary = ".*/[.]?xdg-desktop-portal-hyprland(-wrapped)?",
    type = "screencopy",
    mode = "allow",
})

hl.permission({
    binary = ".*/grim",
    type = "screencopy",
    mode = "allow",
})

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- A border only says where a window ends, drop it when nothing else is tiled next to it.
-- w[tv1]: one visible tiled window, a group counts as one. f[1]: maximized.
-- Floating windows keep theirs, they sit on top of something.
for name, workspace in pairs({ ["no-border-alone"] = "w[tv1]", ["no-border-maximized"] = "f[1]" }) do
    hl.window_rule({
        name = name,
        match = { float = false, workspace = workspace },
        border_size = 0,
    })
end

-- Pinned windows follow across workspaces, the yellow tells them apart. Active then inactive.
hl.window_rule({
    name = "pinned-border",
    match = { pin = true },
    border_color = "rgb(f7d95c) rgb(8a7426)",
})

hl.window_rule({
    name = "float-picture-in-picture",
    match = { title = "^Picture-in-Picture$" },
    float = true,
})

hl.window_rule({
    name = "satty-overlay",
    match = { class = "^com\\.gabm\\.satty$" },
    float = true,
    move = "0 0",
    size = "monitor_w monitor_h",
    border_size = 0,
    rounding = 0,
    no_anim = true,
})

hl.window_rule({
    name = "fix-xwayland-drag",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1,
})
