# THIS WAS WRITTEN BY A CLANKER
{
    # Pruned monerod with view-only RPC served by the `svc-traefik` module at
    # `http://<hostname>.local:18089` (point wallets here as a remote node).
    # P2P is outbound only.
    flake.modules.nixos.svc-monero = { config, ... }: let
        rpcPort = 18081;
        publicRpcPort = 18089;
    in {
        services.monero = {
            enable = true;
            prune = true;
            rpc = {
                address = "127.0.0.1";
                port = rpcPort;
                restricted = true;
            };
        };

        services.traefik = {
            staticConfigOptions.entryPoints.monero-rpc.address = ":${toString publicRpcPort}";
            dynamicConfigOptions.http = {
                routers.monero-rpc = {
                    entryPoints = [ "monero-rpc" ];
                    rule = "PathPrefix(`/`)";
                    service = "monero-rpc";
                };
                services.monero-rpc.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString rpcPort}"; }];
            };
        };

        networking.firewall.allowedTCPPorts = [ publicRpcPort ];

        assertions = [{
            assertion = config.services.traefik.enable;
            message = "the `svc-monero` module RPC is only reachable through the `svc-traefik` module, import it as well.";
        }];
    };
}
