{ ... }: let
    hostname = "mistylake";
in {
    keys.hosts.${hostname} = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0ZgVVQZfW3BYIUT3fa9T1ncUnpIF+X8ZZysapPU5nQ root@mistylake";
    flake.nixosConfigurations.${hostname} = {

    };
}
