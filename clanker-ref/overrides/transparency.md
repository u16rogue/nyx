# Terminal background transparency

Only ghostty's `background-opacity` (0.9) makes anything see-through. It applies to cells with the default background only, so a program is transparent exactly where it does not paint a background itself.

- Dead end: `background-opacity-cells = true`. The cell is drawn at 0.9 over the window background that is also 0.9, the result is 0.99 opaque and looks unchanged. No ghostty setting avoids the stacking.
- neovim: `transparent_background = true` in the catppuccin setup (`overrides/neovim/init.lua`). Statusline, floats and cursorline keep their own background.
- opencode: `overrides/opencode/nyx-catppuccin.json` is the built-in catppuccin theme with `theme.background` set to `none`. It was extracted from the 2.3.0 binary (legacy `defs`/`theme` format, still accepted), so it does not follow upstream changes to the built-in theme.
    - opencode only loads custom themes from `<config dir>/themes/*.json` and `.opencode/themes` of the project. There is no env var for a theme path, `OPENCODE_CONFIG_DIR` moves the whole config dir. So the wrapper's `preHook` symlinks the file into `~/.config/opencode/themes` on every start, same idea as the vesktop seed config.
    - The first frame is painted with opencode's default `#0a0a0a` before custom themes are discovered, a short dark flash at startup.
    - Testing without looking at it: run the built wrapper under `script` with `SHELL=bash` and `--standalone` for about 30 seconds and count `48;2;30;30;46` (the painted base colour) against `49m` (default background) in the typescript.
