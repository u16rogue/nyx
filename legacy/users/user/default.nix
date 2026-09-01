{ username, persist_path, host-custom, ... }: { config, inputs, pkgs, ... }: {
    imports = [
        ((import ./secrets.nix) { inherit username; })

        ((import ./apps/hyprland/default.nix) { inherit username host-custom; })
        ((import ./apps/waybar/default.nix) { inherit username; })
        ((import ./apps/kitty/default.nix) { inherit username; })
        ((import ./apps/fuzzel/default.nix) { inherit username; })
        ((import ./apps/wiremix/default.nix) { inherit username; })
        ((import ./apps/btop/default.nix) { inherit username; })
        ((import ./apps/yazi/default.nix) { inherit username; })

        ((import ./apps/fish/default.nix) { inherit username; })
        ((import ./apps/tmux/default.nix) { inherit username; })
        ((import ./apps/zellij/default.nix) { inherit username; })
        ((import ./apps/nvim/default.nix) { inherit username; })

        ((import ./apps/vesktop/default.nix) { inherit username persist_path; })
        ((import ./apps/keepassxc/default.nix) { inherit username persist_path; })
        ((import ./apps/firefox/default.nix) { inherit username persist_path; })
        ((import ./apps/monero-gui/default.nix) { inherit username persist_path; })
        ((import ./apps/steamguard-cli/default.nix) { inherit username persist_path; })
        ((import ./apps/moonlight-stream/default.nix) { inherit username persist_path; })
        ((import ./apps/remmina/default.nix) { inherit username persist_path; })
    ];

    nixpkgs.overlays = [(final: prev: {
        nushell = ((import ./packs/nushell/package.nix) { inherit inputs; pkgs = prev; });
    })];

    # todo: make this more user centric unless we're making a
    # single user only nix config
    services.pcscd.enable = true;
    programs.gnupg.agent = {
         enable = true;
         pinentryPackage = pkgs.pinentry-curses;
         enableSSHSupport = true;
    };
    # ---

    users.users.${username} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        packages = [];
        shell = pkgs.fish;
        hashedPasswordFile = config.age.secrets."user-password".path;
    };

    age.secrets."user-password" = { file = ../../secrets/user-password.age; mode = "0400"; };

    home-manager.users.${username} = { pkgs, ... }: {
        home = {
            inherit username;
            homeDirectory = "/home/${username}";
            stateVersion = "25.11";
            packages = [
                pkgs.git
                pkgs.openssh
                pkgs.jq
                pkgs.bubblewrap
                pkgs.nushell
            ] ++ ((import ./scripts/default.nix) { inherit pkgs; });

            persistence."${persist_path}" = {
                directories = [
                    "downloads"
                    "media"
                    "documents"
                    "projects"
                ];
                files = [];
            };
            sessionPath = [];
        };

        programs.gpg = {
            enable = true;
        };
    };
}
