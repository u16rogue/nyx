{ ... }: let
    hostname = "mistyriver";
in {
    keys.hosts.${hostname} = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPYWxa99sHJ94Cb69bbD+dBknEJNcVRDerPmsgrEdwFW root@mistyriver";
    flake.nixosConfigurations.${hostname} = {

    };
}
