# overrides/hyprland and per-user desktops

Files: `overrides/hyprland/package.nix`, `hyprland.lua`, `snippets.nix`, `nixos/modules/hyprland-prerequisites.nix`, `nixos/users/user.nix`.

## Host versus user

- `nyx.nixos.users.<name>.host-configuration` is host-wide configuration requested by that user, not a user-scoped module. nyx merges the requests of every user assigned to a host (`nixos/default.nix`). One user requesting Hyprland and another Niri on the same host is fine.
- The host side (`hyprland-prerequisites`) uses stock `pkgs.hyprland` and never sets `programs.hyprland.package`. The configured wrapper is only in the user's package list. Keep it that way: `programs.hyprland.package` is one host-wide value, two users personalizing it would conflict.
- Portal routing is per desktop: `xdg.portal.config.hyprland` becomes `hyprland-portals.conf`. Don't put desktop-specific choices in `xdg.portal.config.common` or set `XDG_CURRENT_DESKTOP` globally.
- PipeWire is not in any host file. It only comes from the user's `host-configuration`. GPU modules are in the host files.
- Separate Unix users have separate user managers, buses and portals. Two graphical sessions under the same UID share them and interfere.
- Display manager defaults are host-wide and stock session entries launch the stock compositor, not the personal wrapper. Here the session is started from a TTY.

## Launch chain

`start-hyprland` from the user's profile is the wrapper's main program. Rejected: a `start-desktop` alias, a `hostConfig` package argument, a runtime service bundle and a `desktop-platform` module. None exist.

1. Public launcher: `uwsm start -U run -g -1 -eD Hyprland -- <session>/bin/start-hyprland`. `-g -1` skips the `graphical.target` wait, `-eD` makes the desktop name exclusive.
2. The private payload is also named `start-hyprland`. uwsm picks its plugin from the binary's basename, renaming it loses the Hyprland plugin that waits for the instance signature.
3. The payload exports `NIXOS_OZONE_WL` and the cursor path, then calls the document portal's `GetMountPoint`. It runs under `errexit`, a failed call aborts startup. See [nixpak.md](nixpak.md) for why this has to happen before any sandboxed app starts.
4. It execs upstream `start-hyprland` by store path with `--config`, so the launcher never re-enters itself.

- Both `share/wayland-sessions` desktop files point at the public launcher. The upstream uwsm entry is replaced by a copy of the plain one because it would nest uwsm.
- The raw `Hyprland` binary is still in the wrapper's `bin/` and bypasses all of this.
- `Super+Shift+X` runs `uwsm stop`. The user moved it off `Super+X` on purpose so it's harder to hit. uwsm already reacts to the compositor exiting, an exit watcher would duplicate it.
- The start hook launches hyprpaper, waybar and mako with `hl.exec_cmd`. Apps are spawned directly, not as supervised units.

## NYX_HYPR_PATH

The helper packages are not on `PATH`. The payload sets `NYX_HYPR_PATH` and only commands built with `resolvePathCommand` in `hyprland.lua` look there, ahead of `PATH`. A new bind that calls a helper has to go through `resolvePathCommand` and the helper has to be in the `NYX_HYPR_PATH` list in `package.nix`. Terminals and apps in the session don't see grim, slurp and the rest unless the user installs them.

## Config generation

- `overridesOpts.monitors` is the only option, fed from `nyx.host.monitors` in `user.nix`. Without monitors the config is `hyprland.lua` as is. With monitors, `snippets.mkMonitor` lines and `mkWorkspaces` lines (enabled monitors only) are appended, so they land after the catch-all `hl.monitor` in the file.
- `snippets.nix`: the output is `desc:<make> <model> [<serial>]` when `edid` is set, else the connector `id`. Mode defaults to `highrr`, position to `auto`.
- `nix run .#hyprland` builds with stock hyprpaper, waybar, mako, fuzzel and ghostty, because `overrides/default.nix` uses `callPackage`. The user passes the nyx overrides explicitly.

## Window movement

The intent is Sway's tabbed workflow on Hyprland groups, not its nested tree.

- `Super+Shift+A/D` reorders the active tab and detaches it at an edge, `W/S` detaches vertically. Workspace moves (`Super+Shift+1..0`) detach the tab first, otherwise the whole group moves. `group_on_movetoworkspace = false` keeps it from joining a group at the destination.
- Directional focus (`focusDirection`): `window_direction_monitor_fallback = false` keeps it on the monitor, both in the neighbor search and the monitor fallback (`Actions::moveFocus`, `CWindowQuery::inDirection`). With `no_focus_fallback` off Hyprland then wraps to the window at the opposite edge. It only wraps a group's tabs when there is one monitor, and does nothing for a window spanning the monitor, so the Lua wraps the tab when the focus dispatch left the active window unchanged.
- `fullscreenSafeMouse`: Super+mouse passes the click through when the workspace under the pointer is fullscreen. A drag that started always gets its release. Possible edge from reading the code: a passed-through press followed by fullscreen ending before release may be taken as a drag start.
- Waybar starts hidden and is toggled with `SIGUSR1` on raw `Super_L` key events.

## Overlays (floating pinned windows)

The `do` block after the mouse binds in `hyprland.lua`. A floating pinned window is click-through and fades under the pointer, Super held or focus on it makes it normal again. The user confirmed the click-through and fade in a live session.

- Click-through is the `no_focus` prop: `ViewHitTester.cpp` skips such windows, so pointer events go to what's below. `FocusState` also refuses to focus them, which is why it has to be lifted while Super is held for Super+drag and Super+Space to reach the window.
- The Lua API has no pointer event. `hl.on` only takes the names in `share/hypr/stubs/hl.meta.lua`, the only input one is `input.keyboard.key` (keycode, time, state). The compositor's `input.mouse.move` is reachable from a C++ plugin only, which could also register a custom event for Lua. Rejected for now in favor of a polling `hl.timer`, the user accepted the lag.
- The timer only runs while some overlay is in passthrough. It's off while Super is held or the overlay is focused.
- `set_prop` recalculates the layout of every active workspace on each call. Only call it on a change, that's what the cached `states` table is for.
- The fade is `opacity_inactive`, not `opacity`: `WindowPresentation::refreshValues` picks the active, inactive or fullscreen alpha by focus, and a passthrough overlay is never focused. The opacity props don't take `unset` (they go through `stof`), reset them with `1`.
- Blur is on by default in Hyprland and the config doesn't turn it off, so a see-through window blurs what's behind it. Overlays get the `no_blur` prop for as long as they are overlays.
- `window.update_state` (float and pin changes) is emitted deferred, the window's state is already final in the handler. Whether a closing window is still listed during `window.close` wasn't checked, the code excludes it by address either way.
- Props set with `set_prop` survive a config reload, the Lua state and its timers don't.

## Validating

`XDG_RUNTIME_DIR=<some dir> <hyprland>/bin/Hyprland --verify-config --config overrides/hyprland/hyprland.lua` runs in the sandbox. It runs the Lua, so it catches unknown key names and invalid arguments of dispatchers constructed at load. Dispatchers constructed inside a bind's function only run on the keypress and aren't checked. Dispatcher arguments aren't in the stubs (`share/hypr/stubs`), they are in the wiki's `content/configuring/core/dispatchers.md` (hyprwm/hyprland-wiki, wiki.hypr.land URLs moved under `configuring/core/`).

A build and config parse don't prove any of this. It needs a fresh login session, an old activation environment hides missing startup setup. Check `hyprctl configerrors`, `systemctl --user status graphical-session.target`, file access from a freshly started nixpak app and real screen sharing. None of that can run in the sandbox.
