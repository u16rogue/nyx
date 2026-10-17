{ ... }: {
    nyx.nixos.users.sysadmin = {
        # ps the password is the sha256sum of the private key for the authorized ssh key cuz im lazy :DD
        password = ''
            -----BEGIN AGE ENCRYPTED FILE-----
            YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IHNzaC1lZDI1NTE5IFgvbUJaQSBtQy9o
            RC9ybDNrd3d2am8vZ2RRc3NTMjFKWGF5MFJHYzFXODFrYnFHM1VZCmlMWko3SXU4
            OTliZzBJRU5jczVlSlhoZ3VmWGhWcGVxZzlDSDIvbGZPNm8KLT4gaixbIn42Li1n
            cmVhc2UgNSA5IC8/ID13CkJwK2RVN0tzUk9yODNqWTl0QndFbXhKWTloQkc4NnBW
            OGRYNWZNQjFveU9mMTNUWDVIWkFrNWlCQ0JyVm5CV2MKMSs1L2FPVThxazZ3V1ho
            UDJnWmNjMU0za3NRanJHR3krMkFiNjdOR0VBYU5EenJSYmNKeTZ2WnU1bUpXaWkw
            Ci0tLSBla0RYRnR4QVJRZ2JMWi9QeEZMaXZjWjRHT2ltaTk3NFpVQW1pRkFRNWRj
            Csty7F4gPpwf8DU0xRlWcQh+MYGkrB1iwi0Wb6hOZY9/3RY4BxYMueYgZuwewCxt
            VEi6RHLFdk2VP24pWIU2+FhvX+TV8A+TiIbRgZs5trunyX8MrunI1cBZpqelUCEc
            chZCC2uD8iB9/nY=
            -----END AGE ENCRYPTED FILE-----
        '';

        ephemeralfs.preserve = {
            files = [];
            directories = [
                ".ssh"
            ];
            partial.directories = [];
        };

        configuration = { pkgs, nyx, ... }: {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDn13+K2p5yC5bbpm0Y9I5AGBLhKQuPRo9oiW/ICQnzf user@mistylake"
            ];
            packages = [
                pkgs.tmux
                pkgs.neovim
                pkgs.git
                pkgs.jq
                pkgs.btop
            ];
        };
    };
}
