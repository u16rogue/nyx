# THIS WAS WRITTEN BY A CLANKER
{
    # Pruned monerod with view-only RPC listening on `<listen.address>:<listen.port>` (localhost by default);
    # exposing it is up to the host. P2P is outbound only.
    flake.modules.nixos.svc-monero = { config, lib, ... }: let
        cfg = config.nyxos.svc-monero;
        loopback = lib.hasPrefix "127." cfg.listen.address || cfg.listen.address == "::1";
    in {
        options.nyxos.svc-monero = {
            listen.address = lib.mkOption {
                description = "Address the restricted RPC binds to. Anything but localhost also needs the port opened in the firewall.";
                type = lib.types.str;
                default = "127.0.0.1";
            };
            listen.port = lib.mkOption {
                description = "Port the restricted RPC listens on.";
                type = lib.types.port;
                default = 18081;
            };
        };

        config.services.monero = {
            enable = true;
            prune = true;
            rpc = {
                inherit (cfg.listen) address port;
                restricted = true;
            };
            # monerod refuses a non-loopback RPC bind without it
            extraConfig = lib.optionalString (!loopback) "confirm-external-bind=1";
        };
    };
}
