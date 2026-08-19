{ self, inputs, ... }: let
    hostname = "mistylake";
in {
    nyx.nixos.hosts.${hostname}.keys = {
        pub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0ZgVVQZfW3BYIUT3fa9T1ncUnpIF+X8ZZysapPU5nQ root@mistylake";
        prv = ''
            -----BEGIN AGE ENCRYPTED FILE-----
            YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IHNjcnlwdCBzSVZNVHRzT2cxK0lMWFFi
            UWVTU25nIDE4CitxMEttaitmWHk0MXNyNFpSY0p6TlZjY1kzR014ZS9IN0NpT2lM
            MlVPcXMKLS0tIFVKOEhRU3dsbTk3ZitXNWJFcHhKdTAzd2c3UUdiSy94R3lNd0c0
            Qjk3K28KMjOXqSZN+Dyrqh/eFVCLgTaPW7cXfIwCGd0yBVyLU8FW0MAn9+sA7Ezv
            E1f3v4Ar71Zxo+2Ou/AJbx1ZGKiMWCbekM6A/+ZNkAW4et6WoBUolZy1Et09EaNe
            52ZKmY7uHCp+cD5p5dj5fwgdmyEIuulyCgF7udSVC0ODuSojnCxiZajszbqsVNvg
            Tg7/JxdyOCvMAiYmiq9208JIUfEdMu0WMz/jKOZENA3dvpY7B64/bFbw9MdhEfeC
            LA4IZ8diJqx+7uqfYpBQQvLD+QCI+goSWrsAS1s/0/hTDbXRVayD+HtoxwQJPLNs
            NRyBkxx+VzDWIkALRy19j5WigUPBmsVBkQX5psebJlJPcWUm1nSKFJI9zhq3Bkqw
            gi+/fRD+ExTMQWEwI4B/gQCkoG2KHStRxqDAPRHfbdzdCZcq4sY7S5lSp8Dk1YQh
            JfWiiwMmbN4HWMG4k6TR+S2OM324Q4fls6a6fCHkBXW4wDeB5jMe8RG74eQx5IuD
            Kk4ArrQ9TaTgz8ll17LLMW9hzeiRtfPdjPcutWISVdnK/6aUScOsMLOv2uOBQH0w
            zS59HS4IUAEmZq8nk4Fdwfg=
            -----END AGE ENCRYPTED FILE-----
        '';
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
