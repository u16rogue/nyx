# TODO:
# Default homepage, newtabs, and new windows to blank
# ddg default search engine (maybe steal from schizo fox searchx)
# add nixpkgs search shortcuts
# set default theme to catpuccin https://addons.mozilla.org/en-US/firefox/addon/catppuccin/
# set tracking protection to strict
# load extensions on build?
# https only + private
# dns over https
# customize toolbar: [sidebars previous next refresh search/url downloads extension]
# auto config sidebery
{ inputs, pkgs, ... }: let
    profileSeed = pkgs.runCommand "nyx-firefox-profile-seed" {} ''
        mkdir -p "$out/.mozilla/firefox/default/chrome"
        cp ${./userChrome.css} "$out/.mozilla/firefox/default/chrome/userChrome.css"

        cat > "$out/.mozilla/firefox/profiles.ini" <<'EOF'
        [Profile0]
        Name=default
        IsRelative=1
        Path=default
        Default=1

        [General]
        StartWithLastProfile=1
        Version=2
        EOF
    '';

    initializedFirefox = inputs.wrappers.lib.wrapPackage {
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
                };

                # AMO's signed latest XPI endpoints keep extension signing enabled.
                Extensions.Install = [
                    "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
                    "https://addons.mozilla.org/firefox/downloads/latest/violentmonkey/latest.xpi"
                    "https://addons.mozilla.org/firefox/downloads/latest/redirector/latest.xpi"
                    "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi"
                    "https://addons.mozilla.org/firefox/downloads/latest/onetab/latest.xpi"
                    "https://addons.mozilla.org/firefox/downloads/latest/sidebery/latest.xpi"
                    "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi"
                    "https://addons.mozilla.org/firefox/downloads/latest/dearrow/latest.xpi"
                    "https://addons.mozilla.org/firefox/downloads/latest/enhancer-for-youtube/latest.xpi"
                    "https://addons.mozilla.org/firefox/downloads/latest/multi-account-containers/latest.xpi"
                    "https://addons.mozilla.org/firefox/downloads/latest/facebook-container/latest.xpi"
                ];
            };
        };
        wrapper = { exePath, ... }: /*bash*/ ''
            profile="$HOME/.mozilla/firefox/default"
            ${pkgs.coreutils}/bin/mkdir -p "$profile/chrome"

            ${pkgs.coreutils}/bin/ln -sfnT "${profileSeed}/.mozilla/firefox/profiles.ini" \
                "$HOME/.mozilla/firefox/profiles.ini"
            ${pkgs.coreutils}/bin/ln -sfnT "${profileSeed}/.mozilla/firefox/default/chrome/userChrome.css" \
                "$profile/chrome/userChrome.css"

            exec ${exePath} -P default "$@"
        '';
    };

    mkNixPak = inputs.nixpak.lib.nixpak {
        inherit (pkgs) lib;
        inherit pkgs;
    };
in (mkNixPak {
    config = { sloth, ... }: {
        app = {
            package = initializedFirefox;
            binPath = "bin/firefox";
        };

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
