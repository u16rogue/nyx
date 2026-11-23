# Terminal background transparency

Only ghostty makes anything see-through (`overrides/ghostty/config.ghostty`). `background-opacity` alone applies to cells with the default background, so nvim and opencode, which paint their own, stay opaque. `background-opacity-cells = true` extends it to every cell, the user confirmed it is visibly see-through and chose it.

- A running ghostty keeps the config it started with. A rebuild only shows after every ghostty window is closed. This once made the option look broken.
- Check what a host really runs before concluding a change had no effect: the ghostty process carries `--config-file=<store path>` in its cmdline, an opencode process has its theme in `OPENCODE_CLI_CONFIG_CONTENT` in its environ.
- Rejected, it was in the repo for a day: not painting the main background per program. neovim is one line (`transparent_background = true` in the catppuccin setup). opencode needs a full copy of the built-in theme with `background` set to `none`, and only loads custom themes from `<config dir>/themes/*.json` or the project's `.opencode/themes`, so the wrapper had to symlink it into `~/.config/opencode/themes`. The first frame also flashed opencode's default `#0a0a0a`.
