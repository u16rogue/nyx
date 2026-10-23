# THIS WAS WRITTEN BY A CLANKER
{
    # Query `<hostname>.local` names without publishing this host.
    flake.modules.nixos.mdns-query = { config, lib, pkgs, ... }: {
        services.avahi = {
            enable = true;
            nssmdns4 = true;
            publish.enable = lib.mkDefault false;
            openFirewall = false;
        };

        # Stable path for sandboxes (eg. firefox) to bind the host's nss-mdns and resolve `.local` without nscd
        environment.etc."nss-mdns".source = pkgs.nssmdns;

        # Only link-local mDNS multicast, instead of all of udp/5353
        networking.firewall.extraInputRules = lib.mkIf config.networking.nftables.enable ''
            ip daddr 224.0.0.251 udp dport 5353 accept
            ip6 daddr ff02::fb udp dport 5353 accept
        '';
        networking.firewall.extraCommands = lib.mkIf (!config.networking.nftables.enable) ''
            iptables -C nixos-fw -p udp -d 224.0.0.251 --dport 5353 -j nixos-fw-accept 2>/dev/null || iptables -A nixos-fw -p udp -d 224.0.0.251 --dport 5353 -j nixos-fw-accept
            ip6tables -C nixos-fw -p udp -d ff02::fb --dport 5353 -j nixos-fw-accept 2>/dev/null || ip6tables -A nixos-fw -p udp -d ff02::fb --dport 5353 -j nixos-fw-accept
        '';
    };
}
