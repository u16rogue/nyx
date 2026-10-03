local mainMod = "SUPER"

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.on("hyprland.start", function()
    -- Hyprland publishes its display environment; UWSM handles readiness and cleanup.
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("waybar")
end)

-- Stop the session in order, rather than removing the compositor before its clients.
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("uwsm stop"))
hl.bind(mainMod .. " + TAB", hl.dsp.group.toggle())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.kill())
hl.bind(mainMod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + GRAVE", hl.dsp.exec_cmd("ghostty"))
hl.bind(mainMod .. " + GRAVE", hl.dsp.exec_cmd("fuzzel"))
hl.bind(mainMod .. " + F1", hl.dsp.dpms({ action = "toggle" }))
hl.bind("CTRL + PRINT", hl.dsp.exec_cmd([=[grim -g "$(slurp -o -r -c '##ff0000ff')" -t png - | satty -f - -o - --fullscreen --actions-on-enter save-to-file --early-exit | wl-copy]=]))

hl.bind(mainMod .. " + D", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + A", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + W", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + S", hl.dsp.focus({ direction = "d" }))

local waybarSignal = hl.dsp.exec_cmd("pkill -SIGUSR1 waybar")
-- Waybar starts hidden: toggle on modifier press, then toggle back on release.
hl.bind(mainMod .. " + SUPER_L", waybarSignal, { ignore_mods = true, transparent = true })
hl.bind(mainMod .. " + SUPER_L", waybarSignal, { ignore_mods = true, transparent = true, release = true })

-- AI-assisted: Sway-like tab movement without moving the whole Hyprland group.
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
        -- Clanker: Workspace moves otherwise carry every tab; detach first and keep this workspace visible.
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
        -- Clanker: Always finish a started drag, even if fullscreen/focus changed before release.
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
        follow_mouse = 0,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
    binds = {
        movefocus_cycles_groupfirst = true,
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
