# Nixpak sandboxed overrides

Applies to the overrides that wrap a package in nixpak, the ones with `sloth` in their `package.nix` (firefox, keepassxc, monero-gui, moonlight-stream, obs-studio, remmina, steamguard-cli, vesktop).

## Shared conventions

- The real home is not mounted. `$HOME/.nyx/app-fake-root/<package>/$HOME` is bound to `$HOME`. The user config has to preserve that directory (`nixos/users/user.nix`).
- In obs-studio and moonlight-stream the sandbox `/tmp` is `$XDG_RUNTIME_DIR/nyx/<package>`, RAM-backed and shared between instances of the app.
- `clearEnv = true`: only the variables listed in `env` reach the app.
- nixpak's `gpu.enable` gives `/dev/dri` and `/run/opengl-driver` but not NVIDIA's own nodes. obs-studio and moonlight-stream list them in `bind.dev`. Only `/dev/nvidia0` is bound, a second NVIDIA GPU is not exposed.
- `bindEntireStore` is false everywhere except obs-studio and moonlight-stream, where it is true so the host NVIDIA driver symlinks resolve.
- nixpak binds are all the `-try` variants. A missing device or a path that isn't mounted yet is skipped silently, the app just doesn't see it.

## Document portal

- A sandbox binds `$XDG_RUNTIME_DIR/doc/by-app/<appId>` to `$XDG_RUNTIME_DIR/doc`. The portal file picker (`QT_QPA_PLATFORMTHEME = "xdgdesktopportal"`) exports the chosen files there.
- Because of `-try`, a sandbox started before the document portal mounted `doc` gets no exports and no error. The Hyprland session payload calls the portal's `GetMountPoint` before starting the compositor for this reason (`overrides/hyprland/package.nix`). Other session launchers need the same.

## obs-studio

- `network = false`. Streaming and remote browser sources can't work until that changes, `etc.sslCertificates` is moot meanwhile.
- There is no recordings bind. Recordings land in the fake home on the host. An earlier README claimed `~/Videos` maps to `~/media/obs`, that was never in the code.
- Wayland only, no X11 socket. Screen capture goes through the `org.freedesktop.portal.Desktop` talk policy and the PipeWire socket.
- No webcam devices are bound.
- Whether NVENC shows up was not verified. nixpkgs' obs-studio takes `cudaSupport` from `config.cudaSupport` and the flake only sets `allowUnfree`.

## moonlight-stream

- VA-API's NVIDIA driver fails to export surfaces in the sandbox and Qt's OpenGL RHI can't create an EGL context. `LIBVA_DRIVER_NAME = "disabled"` and `QSG_RHI_BACKEND = "vulkan"` work around both, don't remove them.
