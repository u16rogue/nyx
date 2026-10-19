# THIS WAS WRITTEN BY A CLANKER
{
    # Single entry point for every web service on the host. Services listen on
    # localhost only and add their own routers to `services.traefik.dynamicConfigOptions`.
    flake.modules.nixos.svc-traefik = {
        services.traefik = {
            enable = true;
            staticConfigOptions = {
                entryPoints.web.address = ":80";
                log.level = "INFO";
            };
        };

        networking.firewall.allowedTCPPorts = [ 80 ];
    };
}
