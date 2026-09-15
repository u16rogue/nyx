{ inputs, pkgs, lib, ... }: let
    addons = import ./addons.nix;
    addon_xpis = lib.flip pkgs.lib.mapAttrs addons (name: addon: pkgs.fetchurl {
        name = "${name}-${addon.version}.xpi";
        inherit (addon) url sha256;
    });
    profile_seed = ./profile-seed;
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
                    DisableFormHistory = true;
                    ExtensionSettings = lib.mapAttrs (name: addon: {
                        installation_mode = "force_installed";
                        install_url = "file://${addon_xpis.${name}}";
                    }) addons;
                    EnableTrackingProtection = {
                        Value = true;
                        Category = "strict";
                        BaselineExceptions = true;
                        ConvenienceExceptions = false;
                    };
                    Homepage = {
                        URL = "about:blank";
                        StartPage = "none";
                        NewTabOnRestore = false;
                    };
                    NewTabPage = false;
                    HttpsOnlyMode = "enabled";
                    DNSOverHTTPS = {
                        Enabled = true;
                        ProviderURL = "1.1.1.1";
                        Fallback = false;
                    };
                    NetworkPrediction = false;
                    PromptForDownloadLocation = true;
                    SearchEngines = {
                        Default = "DuckDuckGo";
                        DefaultPrivate = "DuckDuckGo";
                        Add = [
                            {
                                Name = "Nixpkgs";
                                Alias = "@nixpkgs";
                                URLTemplate = "https://search.nixos.org/packages?channel=unstable&query={searchTerms}";
                            }
                        ];
                    };
                    SearchSuggestEnabled = false;
                    Preferences = lib.mapAttrs (_: value: value // { Status = value.Status or "user"; }) {
                        "toolkit.legacyUserProfileCustomizations.stylesheets".Value = true;
                        "browser.link.open_newwindow.restriction".Value = 0;
                        "privacy.userContext.newTabContainerOnLeftClick.enabled".Value = true;
                        "extensions.autoDisableScopes".Value = 0;
                        "extensions.activeThemeID".Value = addons.catppuccin.extid;
                        "browser.ctrlTab.sortByRecentlyUsed".Value = true;
                        "browser.tabs.hoverPreview.showThumbnails".Value = false;
                        "browser.toolbars.bookmarks.visibility".Value = "never";
                        "browser.urlbar.showSearchTerms.enabled".Value = false;
                        "browser.urlbar.suggest.bookmark".Value = false;
                        "browser.urlbar.suggest.engines".Value = false;
                        "browser.urlbar.suggest.history".Value = false;
                        "browser.urlbar.suggest.openpage".Value = false;
                        "browser.urlbar.suggest.quickactions".Value = false;
                        "browser.urlbar.suggest.recentsearches".Value = false;
                        "browser.urlbar.suggest.topsites".Value = false;
                        "general.smoothScroll".Value = false;
                        "network.http.speculative-parallel-limit".Value = 0;
                        "network.prefetch-next".Value = false;
                        "privacy.bounceTrackingProtection.mode".Value = 1;
                        "privacy.globalprivacycontrol.enabled".Value = true;
                        "privacy.query_stripping.enabled".Value = true;
                        "privacy.query_stripping.enabled.pbmode".Value = true;
                    };
                };
            };
            wrapper = { exePath, ... }: /*bash*/ ''
                profile="$HOME/.mozilla/firefox/default"
                ${pkgs.coreutils}/bin/mkdir -p "$profile/chrome"

                ${pkgs.coreutils}/bin/ln -sfnT "${profile_seed}/profiles.ini" \
                    "$HOME/.mozilla/firefox/profiles.ini"
                ${pkgs.coreutils}/bin/ln -sfnT "${profile_seed}/default/user.js" \
                    "$profile/user.js"
                ${pkgs.coreutils}/bin/ln -sfnT "${profile_seed}/default/chrome/userChrome.css" \
                    "$profile/chrome/userChrome.css"

                extension_dir="$profile/extensions"
                ${pkgs.coreutils}/bin/mkdir -p "$extension_dir"
                ${pkgs.lib.concatStringsSep "\n" (lib.flip lib.mapAttrsToList addons (name: addon: /*bash*/ ''
                    # allows firefox to replace the symlink with an updated xpi addon allowing updates
                    if [[ ! -e "$extension_dir/${addon.extid}.xpi" ]]; then
                        ${pkgs.coreutils}/bin/ln -s "${addon_xpis.${name}}" "$extension_dir/${addon.extid}.xpi"
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
