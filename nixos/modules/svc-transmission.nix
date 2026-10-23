# THIS WAS WRITTEN BY A CLANKER
{
    # Transmission with its RPC and web panel (`<subpath>/web/`) listening on `<listen.address>:<listen.port>`
    # (localhost by default); exposing it is up to the host.
    # The login lives outside the store in `services.transmission.credentialsFile` (set by the host), a JSON
    # object like `{ "rpc-username": "...", "rpc-password": "..." }`.
    # Downloads land in `<home>/Downloads`, readable by members of the `transmission` group (eg. a media server).
    flake.modules.nixos.svc-transmission = { config, lib, ... }: let
        cfg = config.nyxos.svc-transmission;
        loopback = lib.hasPrefix "127." cfg.listen.address || cfg.listen.address == "::1";
    in {
        options.nyxos.svc-transmission = {
            listen.address = lib.mkOption {
                description = "Address the RPC and web panel bind to. Anything but localhost also needs the port opened in the firewall.";
                type = lib.types.str;
                default = "127.0.0.1";
            };
            listen.port = lib.mkOption {
                description = "Port the RPC and web panel listen on.";
                type = lib.types.port;
                default = 9091;
            };
            subpath = lib.mkOption {
                description = "Path the RPC and web panel are served under, kept by the proxy (no prefix stripping).";
                type = lib.types.strMatching "(/[^/]+)*";
                default = "/transmission";
            };
        };

        config = {
            services.transmission = {
                enable = true;
                openPeerPorts = true;
                settings = {
                    rpc-bind-address = cfg.listen.address;
                    rpc-port = cfg.listen.port;
                    rpc-url = "${cfg.subpath}/";
                    rpc-authentication-required = true;
                    rpc-host-whitelist-enabled = false;
                    rpc-whitelist-enabled = lib.mkIf (!loopback) (lib.mkDefault false);
                };
            };

            assertions = [{
                assertion = config.services.transmission.credentialsFile != "/dev/null";
                message = "the `svc-transmission` module requires a login, set `services.transmission.credentialsFile`.";
            }];
        };
    };
}
