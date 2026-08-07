{ self, inputs, ... }: let
    hostname = "mistylake";
in {
    nyx.nixos.hosts.${hostname}.keys = {
        pub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0ZgVVQZfW3BYIUT3fa9T1ncUnpIF+X8ZZysapPU5nQ root@mistylake";
        prv = null;
    };
    flake.nixosConfigurations.${hostname} = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
            inherit hostname;
        };
        modules = [
            self.modules.nixos."users.user"
        ];
    };
}
