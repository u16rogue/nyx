// workaround until zellij-org/zellij#5653 ships: side-by-side bar plugins aren't detected as a bar, so with
// frames off they reserve a boundary row and a size=1 bar gets drawn over. full frames skip that for
// borderless panes, so tiled panes here need borderless=true to stay frameless
pane_frames true
pane_frame_style "full"

keybinds {
    shared {
        bind "Alt 1" { GoToTab 1; }
        bind "Alt 2" { GoToTab 2; }
        bind "Alt 3" { GoToTab 3; }
        bind "Alt f" { ToggleFloatingPanes; }
    }
}

layout {
    default_tab_template {
        pane size=1 split_direction="vertical" {
            pane size=55 borderless=true {
                plugin location="compact-bar"
            }
            pane borderless=true {
                plugin location="status-bar"
            }
        }
        children
    }

    swap_floating_layout {
        floating_panes max_panes=1 {
            pane x="5%" y="5%" width="90%" height="90%"
        }
    }

    tab name=" " focus=true {
        pane name="neovim" borderless=true start_suspended=true command="sh" {
            args "-c" "if [ -f .nvimsession ]; then exec nvim -S .nvimsession; else exec nvim; fi"
        }
    }

    tab name=" " split_direction="horizontal" {
        {{#ssm_zellij_panes}}
        {{.}}
        {{/ssm_zellij_panes}}
        {{^ssm_zellij_panes}}
        pane borderless=true start_suspended=true command="$SHELL"
        {{/ssm_zellij_panes}}
    }

    tab name="󱚠 " split_direction="horizontal" {
        pane name="clanker" borderless=true start_suspended=true command="opencode" {
            args "--standalone"
        }
    }
}
