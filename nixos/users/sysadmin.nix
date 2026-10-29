{ inputs, ... }: {
    nyx.nixos.users.sysadmin = {
        # ps the password is the sha256sum of the private key for the authorized ssh key cuz im lazy :DD
        password = ''
            -----BEGIN AGE ENCRYPTED FILE-----
            YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IHNzaC1lZDI1NTE5IFgvbUJaQSBtQy9o
            RC9ybDNrd3d2am8vZ2RRc3NTMjFKWGF5MFJHYzFXODFrYnFHM1VZCmlMWko3SXU4
            OTliZzBJRU5jczVlSlhoZ3VmWGhWcGVxZzlDSDIvbGZPNm8KLT4gaixbIn42Li1n
            cmVhc2UgNSA5IC8/ID13CkJwK2RVN0tzUk9yODNqWTl0QndFbXhKWTloQkc4NnBW
            OGRYNWZNQjFveU9mMTNUWDVIWkFrNWlCQ0JyVm5CV2MKMSs1L2FPVThxazZ3V1ho
            UDJnWmNjMU0za3NRanJHR3krMkFiNjdOR0VBYU5EenJSYmNKeTZ2WnU1bUpXaWkw
            Ci0tLSBla0RYRnR4QVJRZ2JMWi9QeEZMaXZjWjRHT2ltaTk3NFpVQW1pRkFRNWRj
            Csty7F4gPpwf8DU0xRlWcQh+MYGkrB1iwi0Wb6hOZY9/3RY4BxYMueYgZuwewCxt
            VEi6RHLFdk2VP24pWIU2+FhvX+TV8A+TiIbRgZs5trunyX8MrunI1cBZpqelUCEc
            chZCC2uD8iB9/nY=
            -----END AGE ENCRYPTED FILE-----
        '';

        ephemeralfs.preserve = {
            files = [];
            directories = [];
            partial.directories = [];
        };

        configuration = { pkgs, nyx, ... }: let shell = nyx.pkgs.fish; in {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            inherit shell;
            openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDn13+K2p5yC5bbpm0Y9I5AGBLhKQuPRo9oiW/ICQnzf " ];
            packages = [
                shell
                (inputs.wrappers.lib.wrapPackage {
                    inherit pkgs;
                    package = pkgs.tmux;
                    flags."-f" = pkgs.writeText "tmux.conf" ''
                        set-option -g base-index 1
                        set-option -g clock-mode-style 24
                        set-option -sg escape-time 1
                        set-option -g prefix C-q
                        bind-key C-q send-prefix
                        set-option -g detach-on-destroy off
                        set-option -ga terminal-overrides ",xterm-256color:Tc"
                        bind-key \` display-popup
                        bind j select-pane -D
                        bind k select-pane -U
                        bind h select-pane -L
                        bind l select-pane -R
                        bind -r W select-pane -t .+1 \; resize-pane -Z

                        set -g window-status-current-style default
                        set-option -g status-position top
                        set-option -g status-interval 5
                        set-option -g status-justify left
                        set-option -g status-style "bg=default,fg=white"
                        set-option -g status-left-length 32
                        set-option -g status-left "#[fg=black,bg=blue,bold] #S #[default] "
                        set-option -g status-right-length 64
                        set-option -g status-right "#{?client_prefix,#[fg=black]#[bg=yellow]#[bold] PREFIX #[default] ,}#[fg=brightblack]#H #[fg=white]%H:%M "
                        set-option -g window-status-separator " "
                        set-option -g window-status-format "#[fg=brightblack] #I #W#{?window_zoomed_flag, (z),} "
                        set-option -g window-status-current-format "#[fg=black,bg=white,bold] #I #W#{?window_zoomed_flag, (z),} "
                        set-option -g window-status-activity-style "fg=yellow"
                        set-option -g pane-border-style "fg=brightblack"
                        set-option -g pane-active-border-style "fg=blue"
                        set-option -g message-style "bg=default,fg=yellow"
                        set-option -g message-command-style "bg=default,fg=yellow"
                        set-option -g mode-style "bg=blue,fg=black"
                        set-option -g clock-mode-colour blue
                    '';
                })
            ];
        };
    };
}
