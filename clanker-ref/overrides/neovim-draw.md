# overrides/neovim draw mode

`lua/draw/` in the neovim override. `<leader>d` or `:Draw` toggles it for the current buffer and window. `init.lua` is the mode, the mouse and the gestures, `model.lua` parses and renders, `route.lua` routes lines.

## Design

- The buffer text is the only state. Nothing is kept beside it, no sidecar, no extmark bookkeeping. `modelParse` runs again whenever `changedtick` moved, so undo, hand edits and a reopened file all work. Rejected: an in-memory object list (lost on restart, wrong after undo) and a sidecar file.
- Every cell of a shape has a mask of the directions it connects in. Parsing takes boxes out of the masks first (smallest closed rectangle per top left corner, its bits are subtracted), then follows lines through what is left. Rendering ORs the masks of all shapes, which is where `┼` and `├` come from. A cell with no claimed bits is background and is written back byte for byte.
- Attachment is geometric and found again at every parse: a line end whose next cell, or own cell, is on the box side facing it. So a line is attached exactly when it looks attached.
- A gesture keeps the model from the press as its base. Every drag event builds a frame from that base, never from the previous frame, and `frameApply` puts back the rows an earlier frame touched. Only rows that differ are written, and a row that differs only in trailing blanks is left alone.
- Moving a box moves a rect: the box, the shapes fully inside it and the background in it. A region selection is the same thing without a picked shape.
- Lines attached to a moved box are routed from scratch (`lineReroute`), a hand shaped route is not kept. An end may change to another side of its box when that scores better by more than `SIDE_SWITCH_COST`. Before this lines kept their side and wrapped around their own box.
- The router scores a fixed set of candidates (straight, L, Z, detour lanes): 10 per bend, 1 per cell, 100 per cell inside any box. Candidate order breaks ties.

## Not obvious

- The winbar is the toolbar. A buffer local `<LeftMouse>` mapping swallows the click before any `%@` click handler would run, so the mapping finds the entry from `getmousepos().wincol` and the spans `barUpdate` kept. A winbar wider than the window is cut on the left and the spans stop matching, hence the keys only fallback.
- The cell under the mouse is computed from `winrow`, `wincol`, `textoff`, `topline` and `leftcol`, not from `getmousepos().line` and `.column`: the canvas goes past the end of a line and of the buffer, where there is no text position to report. This needs `nowrap` and `nofoldenable`, both set while the mode is on.
- Window options are set with `scope = 'local'`. `vim.wo[win].x = v` acts like `:set` and would change the global value too.
- The drag frames are joined into one undo step with `undojoin` before every write after the first.
- `ibl` is turned off for the buffer and `vim.b.completion = false` stops blink while the mode is on.
- Text is typed in Replace mode so a box border isn't pushed. `<CR>` is mapped to move down to the column the text started in, a real line break would shift everything below.
- A style that doesn't show (rounded on a line without corners) doesn't survive the parse. The selection is matched by geometry only for that reason.
- Only unicode box drawing is parsed. `+--+` ascii boxes are background.

## Testing

- In a headless script everything is one undo step, which hides undo bugs. Break it with `let &undolevels = &undolevels` before each gesture, and drive `press`, `drag` and `release` (they take cells) to exercise gestures without a mouse.
- The mouse path needs a real UI. What works: start `nvim --listen <sock>` inside `tmux -L <name> new-session -d -x 110 -y 24`, then from a second `nvim --headless -l` script `sockconnect('pipe', sock, { rpc = true })` and `rpcrequest` `nvim_input_mouse` and `nvim_input`. Follow each mouse event with a cheap request like `nvim_eval` so it is processed in order. `tmux capture-pane -p` shows the screen. The grid row of buffer line 1 is `winrow - 1 + winbar` from `getwininfo`.
- Dead end: `nvim_ui_attach` over rpc from an nvim client fails, the client can't take the redraw notifications.
- Don't `pkill -f` a pattern that is also in your own command line, it kills the shell.
