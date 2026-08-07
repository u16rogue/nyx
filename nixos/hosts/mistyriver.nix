{ ... }: let
    hostname = "mistyriver";
in {
    nyx.nixos.hosts.${hostname}.keys = {
        pub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPYWxa99sHJ94Cb69bbD+dBknEJNcVRDerPmsgrEdwFW root@mistyriver";
        prv = null;
    };
    flake.nixosConfigurations.${hostname} = {

    };
}
