# Sandboxes a web browser
# TODO: add bookmark by default: moz-extension://2663cd4c-0553-4417-87d1-92fb07ff1b43/onetab.html
{ username, persist_path }: { config, pkgs, inputs, system, ... }: let
    jail = inputs.jail-nix.lib.init pkgs;
in {
    home-manager.users.${username} = { config, lib, ... }: {

        home.persistence."${persist_path}".directories = [ ".emulated-root/firefox/home/${username}" ];

        # Trick home-manager into generating the profile into our sandbox directory
        # by symlinking the destination
        home.activation.linkFirefox = lib.hm.dag.entryAfter ["writeBoundary"] /*bash*/ ''
            mkdir -p ~/.emulated-root/firefox/home/${username}/.mozilla
            ln -sf ~/.emulated-root/firefox/home/${username}/.mozilla ~/
            if [ ! -e ~/downloads/firefox-downloads ]; then
                ln -sf ~/.emulated-root/firefox/home/${username}/downloads ~/downloads/firefox-downloads
            fi
        '';

        xdg.desktopEntries.firefox = {
            name = "Firefox";
            exec = "firefox -P \"default\"";
            icon = "${pkgs.firefox}/share/icons/hicolor/48x48/apps/firefox.png";
            terminal = false;
            categories = [ "Network" "WebBrowser" ];
            mimeType = [ "text/html" "text/xml" ];
        };

        programs.firefox = {
            enable = true;
            configPath = ".mozilla/firefox";
            package = jail "firefox" pkgs.firefox (with jail.combinators; [
                  network
                  gui
                  gpu
                  pipewire
                  (dbus { talk = [ "org.freedesktop.portal.Desktop" ]; })
                  (rw-bind (noescape "~/.emulated-root/firefox/home/${username}") (noescape "~/"))
                  (add-runtime /*bash*/ ''
                      while read -r link; do
                          ABS="''$(realpath "''$link")"
                          RUNTIME_ARGS+=("--ro-bind" "''$ABS" "''$ABS")
                          # rebuild symlinks
                          next_link=""
                          prev_link="''$(readlink "''$link")"                           # 1. `link` is guaranteed to be a symlink, get where it goes (eg. ~/.mozilla/firefox/profiles.ini -> ...home-manager-files)
                          while [ -L "''$prev_link" ]; do                               # 2. is that also a symlink? if its the real file then `link` is already complete, nothing to do. (eg. ...home-manager-files? yes.)
                              next_link="''$(readlink "''$prev_link")"                  # 3. load where that symlink goes (eg ...home-manager-files -> /nix/store/...profiles.ini)
                              RUNTIME_ARGS+=("--symlink" "''$next_link" "''$prev_link") # 4. and create the symlink (eg "--symlink /nix/store/...profiles.ini ...home-manager-files")
                              prev_link="''$next_link"                                  #
                          done                                                          # 5. ... the nix store file is the real file, host symlink chain is rebuilt, loop ends! ~/.mozilla/firefox/profiles.ini -> ...home-manager-files -> /nix/store/...profiles.ini
                      done <<< "''$(find ~/.mozilla/firefox -type l ! -name ".keep" ! -name "lock")"
                  '')
            ]);
            policies = {};
            profiles.default = {
                id = 0;
                name = "default";
                isDefault = true;
                userChrome = ''
                    #nav-bar { /* make the navbar compact */
                      margin-top: -42px;
                      box-shadow: none !important;
                    }
                    
                    #main-window[privatebrowsingmode="temporary"] #nav-bar { /* if in private browsing, show the "private browsing" */
                      margin-right: 138px;
                    }

                    toolbarbutton[class="titlebar-button titlebar-close"] { /* removes the close button on the top right */
                        display: none;
                    }

                    #sidebar-header {
                        display: none !important;
                    }
                '';
                settings = {
                    "extensions.autoDisableScopes" = 0; # bypass extension "enable" prompt
                    "toolkit.legacyUserProfileCustomizations.stylesheets" = true; # enable userchrome custom css
                    "browser.link.open_newwindow.restriction" = 0; # force window popups to be new tabs. window popups uses a minimal UI that removes access to extensions (eg payment providers that require js, cant toggle)
                    "privacy.userContext.newTabContainerOnLeftClick.enabled" = true; # Settings > Containers > Settings... > Select a container for each new tab
                };
                extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
                   # Behavior
                   ublock-origin
                   violentmonkey
                   redirector
                   user-agent-string-switcher
                   # Style
                   darkreader
                   # Tabs
                   onetab
                   sidebery
                   # Unsloppify: Youtube
                   sponsorblock
                   dearrow
                   enhancer-for-youtube
                   # Containers
                   multi-account-containers
                   facebook-container
               ];
            };
        };
    };
}
