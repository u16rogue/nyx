# THIS WAS WRITTEN BY A CLANKER
{
    # Jellyfin served by the `svc-traefik` module at `http://<hostname>.local/jellyfin`.
    # The first visitor gets the setup wizard and becomes the admin; libraries are added from the dashboard.
    flake.modules.nixos.svc-jellyfin = { config, lib, pkgs, ... }: let
        port = 8096;
        subpath = "/jellyfin";
        cfg = config.services.jellyfin;

        # Listen address and base URL have no NixOS option, they live in Jellyfin's `network.xml`.
        # Seeded only when missing so the dashboard can still change the other network settings.
        networkXml = pkgs.writeText "network.xml" ''
            <?xml version="1.0" encoding="utf-8"?>
            <NetworkConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
              <BaseUrl>${subpath}</BaseUrl>
              <InternalHttpPort>${toString port}</InternalHttpPort>
              <LocalNetworkAddresses>
                <string>127.0.0.1</string>
              </LocalNetworkAddresses>
              <KnownProxies>
                <string>127.0.0.1</string>
              </KnownProxies>
              <AutoDiscovery>false</AutoDiscovery>
              <EnableUPnP>false</EnableUPnP>
            </NetworkConfiguration>
        '';
    in {
        services.jellyfin.enable = true;

        systemd.services.jellyfin.preStart = lib.mkBefore ''
            if [[ ! -e ${lib.escapeShellArg "${cfg.configDir}/network.xml"} ]]; then
                install -D -m 600 ${networkXml} ${lib.escapeShellArg "${cfg.configDir}/network.xml"}
            fi
        '';

        services.traefik.dynamicConfigOptions.http = {
            routers.jellyfin = {
                entryPoints = [ "web" ];
                # Jellyfin expects the base URL to be kept, so no prefix stripping
                rule = "Path(`${subpath}`) || PathPrefix(`${subpath}/`)";
                service = "jellyfin";
            };
            services.jellyfin.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString port}"; }];
        };

        assertions = [{
            assertion = config.services.traefik.enable;
            message = "the `svc-jellyfin` module is only reachable through the `svc-traefik` module, import it as well.";
        }];
    };
}
