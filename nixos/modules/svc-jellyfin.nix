# THIS WAS WRITTEN BY A CLANKER
{
    # Jellyfin listening on `<listen.address>:<listen.port>` (localhost by default) under `<subpath>`; exposing it is up to the host.
    # The first visitor gets the setup wizard and becomes the admin; libraries are added from the dashboard.
    flake.modules.nixos.svc-jellyfin = { config, lib, pkgs, ... }: let
        cfg = config.nyxos.svc-jellyfin;
        jellyfin = config.services.jellyfin;

        # Listen address and base URL have no NixOS option, they live in Jellyfin's `network.xml`.
        # Seeded only when missing so the dashboard can still change the other network settings.
        networkXml = pkgs.writeText "network.xml" ''
            <?xml version="1.0" encoding="utf-8"?>
            <NetworkConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
              <BaseUrl>${cfg.subpath}</BaseUrl>
              <InternalHttpPort>${toString cfg.listen.port}</InternalHttpPort>
              <LocalNetworkAddresses>
                ${lib.optionalString (!builtins.elem cfg.listen.address [ "0.0.0.0" "::" ]) "<string>${cfg.listen.address}</string>"}
              </LocalNetworkAddresses>
              <KnownProxies>
                <string>127.0.0.1</string>
              </KnownProxies>
              <AutoDiscovery>false</AutoDiscovery>
              <EnableUPnP>false</EnableUPnP>
            </NetworkConfiguration>
        '';
    in {
        options.nyxos.svc-jellyfin = {
            listen.address = lib.mkOption {
                description = ''
                    Address Jellyfin binds to, `0.0.0.0` or `::` for all. Anything but localhost also needs the port
                    opened in the firewall. Only seeded into a new `network.xml`.
                '';
                type = lib.types.str;
                default = "127.0.0.1";
            };
            listen.port = lib.mkOption {
                description = "Port Jellyfin listens on. Only seeded into a new `network.xml`.";
                type = lib.types.port;
                default = 8096;
            };
            subpath = lib.mkOption {
                description = "Base URL Jellyfin serves under, kept by the proxy (no prefix stripping). Only seeded into a new `network.xml`.";
                type = lib.types.strMatching "(/[^/]+)*";
                default = "";
                example = "/jellyfin";
            };
        };

        config = {
            services.jellyfin.enable = true;
            systemd.services.jellyfin.preStart = lib.mkBefore ''
                if [[ ! -e ${lib.escapeShellArg "${jellyfin.configDir}/network.xml"} ]]; then
                    install -D -m 600 ${networkXml} ${lib.escapeShellArg "${jellyfin.configDir}/network.xml"}
                fi
            '';
        };
    };
}
