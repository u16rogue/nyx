# TODO:
# Default homepage, newtabs, and new windows to blank
# ddg default search engine (maybe steal from schizo fox searchx)
# add nixpkgs search shortcuts
# set tracking protection to strict
# https only + private
# dns over https
# auto config sidebery
{ inputs, pkgs, lib, ... }: let
    addons = import ./addons.nix;
    addonXpis = lib.flip pkgs.lib.mapAttrs addons (name: addon: pkgs.fetchurl {
        name = "${name}-${addon.version}.xpi";
        inherit (addon) url sha256;
    });
    profileSeed = ./profile-seed;
    mkNixPak = inputs.nixpak.lib.nixpak {
        inherit (pkgs) lib;
        inherit pkgs;
    };
in (mkNixPak {
    config = { sloth, ... }: {
        app.package = inputs.wrappers.lib.wrapPackage {
            inherit pkgs;
            package = pkgs.wrapFirefox pkgs.firefox-unwrapped {
                extraPolicies = {
                    DisableTelemetry = true;
                    DisableFirefoxStudies = true;
                    DisablePocket = true;
                    OfferToSaveLogins = false;

                    Preferences = {
                        "toolkit.legacyUserProfileCustomizations.stylesheets" = {
                            Value = true;
                            Status = "user";
                        };
                        "browser.link.open_newwindow.restriction" = {
                            Value = 0;
                            Status = "user";
                        };
                        "privacy.userContext.newTabContainerOnLeftClick.enabled" = {
                            Value = true;
                            Status = "user";
                        };
                        "extensions.autoDisableScopes" = {
                            Value = 0;
                            Status = "user";
                        };
                        "extensions.activeThemeID" = {
                            Value = addons.catppuccin.extid;
                            Status = "user";
                        };
                    };
                };
            };
            wrapper = { exePath, ... }: /*bash*/ ''
                profile="$HOME/.mozilla/firefox/default"
                ${pkgs.coreutils}/bin/mkdir -p "$profile/chrome"

                toolbar_layout="$profile/.nyx-toolbar-layout"
                # Do not write preferences while an existing Firefox owns this profile.
                if [[ ! -e "$toolbar_layout" && ! -e "$profile/lock" && ! -e "$profile/.parentlock" ]]; then
                    printf '\n' >> "$profile/prefs.js"
                    ${pkgs.coreutils}/bin/cat "${profileSeed}/default/prefs.js" >> "$profile/prefs.js"
                    ${pkgs.coreutils}/bin/touch "$toolbar_layout"
                fi

                ${pkgs.coreutils}/bin/ln -sfnT "${profileSeed}/profiles.ini" \
                    "$HOME/.mozilla/firefox/profiles.ini"
                ${pkgs.coreutils}/bin/ln -sfnT "${profileSeed}/default/chrome/userChrome.css" \
                    "$profile/chrome/userChrome.css"

                extension_dir="$profile/extensions"
                ${pkgs.coreutils}/bin/mkdir -p "$extension_dir"
                ${pkgs.lib.concatStringsSep "\n" (lib.flip lib.mapAttrsToList addons (name: addon: /*bash*/ ''
                    if [[ ! -e "$extension_dir/${addon.extid}.xpi" ]]; then
                        ${pkgs.coreutils}/bin/ln -s "${addonXpis.${name}}" "$extension_dir/${addon.extid}.xpi"
                    fi
                ''))}

                exec ${exePath} -P default "$@"
            '';
        };
        app.binPath = "bin/firefox";
        flatpak.appId = "org.mozilla.firefox";
        dbus.policies."org.freedesktop.portal.Desktop" = "talk";
        bubblewrap = {
            network = true;
            bindEntireStore = false;
            clearEnv = true;
            newSession = true;
            dieWithParent = true;
            sockets.wayland = true;

            bind.rw = [
                [ (sloth.mkdir (sloth.concat [ (sloth.env "HOME") "/.nyx/app-fake-root/firefox/" (sloth.env "HOME") ])) (sloth.env "HOME") ]
                [ (sloth.mkdir "/tmp/.nyx-tmp/firefox") "/tmp" ]
                (sloth.concat' sloth.runtimeDir "/doc") # for document portal
            ];

            env = {
                HOME = sloth.env "HOME";
                XDG_RUNTIME_DIR = sloth.runtimeDir;
                WAYLAND_DISPLAY = sloth.envOr "WAYLAND_DISPLAY" "wayland-0";
                MOZ_ENABLE_WAYLAND = "1";
            };
        };
    };
}).config.env
