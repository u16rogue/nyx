# THIS WAS WRITTEN BY A CLANKER
{
    # Transmission with its web panel served by the `svc-traefik` module at `http://<hostname>.local/transmission/web/`.
    # The login lives outside the store in `services.transmission.credentialsFile` (set by the host), a JSON
    # object like `{ "rpc-username": "...", "rpc-password": "..." }`.
    # Downloads land in `<home>/Downloads`, readable by members of the `transmission` group (eg. a media server).
    flake.modules.nixos.svc-transmission = { config, lib, ... }: let
        port = 9091;
        subpath = "/transmission";
    in {
        services.transmission = {
            enable = true;
            # Incoming peers (still needs a port forward on the router to be reachable from outside)
            openPeerPorts = true;
            settings = {
                rpc-bind-address = "127.0.0.1";
                rpc-port = port;
                rpc-url = "${subpath}/";
                rpc-authentication-required = true;
                # Requests come through traefik with the LAN Host header; the RPC only listens on localhost anyway
                rpc-host-whitelist-enabled = false;
            };
        };

        services.traefik.dynamicConfigOptions.http = {
            routers.transmission = {
                entryPoints = [ "web" ];
                rule = "PathPrefix(`${subpath}/`)";
                service = "transmission";
            };
            services.transmission.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString port}"; }];
        };

        assertions = [
            {
                assertion = config.services.traefik.enable;
                message = "the `svc-transmission` module is only reachable through the `svc-traefik` module, import it as well.";
            }
            {
                assertion = config.services.transmission.credentialsFile != "/dev/null";
                message = "the `svc-transmission` module requires a login, set `services.transmission.credentialsFile`.";
            }
        ];
    };
}
