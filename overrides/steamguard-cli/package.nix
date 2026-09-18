{ inputs, pkgs, steamguard-cli, ... }: let
    mkNixPak = inputs.nixpak.lib.nixpak {
        inherit (pkgs) lib;
        inherit pkgs;
    };
in (mkNixPak {
    config = { sloth, ... }: {
        app = {
            package = steamguard-cli;
            binPath = "bin/steamguard";
        };
        bubblewrap = {
            network = true;
            bindEntireStore = false;
            clearEnv = true;
            newSession = true;
            dieWithParent = true;
            bind.rw = [
                [ (sloth.mkdir (sloth.concat [ (sloth.env "HOME") "/.nyx/app-fake-root/steamguard-cli/" (sloth.env "HOME") ])) (sloth.env "HOME") ]
                [ (sloth.mkdir "/tmp/.nyx-tmp/steamguard-cli") "/tmp" ]
            ];
            env = {
                HOME = sloth.env "HOME";
                RUST_BACKTRACE = "full";
            };
        };
    };
}).config.env
