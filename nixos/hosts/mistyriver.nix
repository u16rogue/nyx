{ ... }: let
    hostname = "mistyriver";
in {
    nyx.nixos.hosts.${hostname}.keys = {
        pub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPYWxa99sHJ94Cb69bbD+dBknEJNcVRDerPmsgrEdwFW root@mistyriver";
        prv = {
            age = ''
                -----BEGIN AGE ENCRYPTED FILE-----
                YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IHNjcnlwdCB3Zml6dTgycjArek4xU09W
                MEpSbnFRIDE5CmJONTVrdHBRM1B5bHlocHA5VVdiQjdFTUcrcjhxZ1ovRE56OGhi
                TVlKNzQKLS0tIEhVSlBzc2ZLQ0tEYjNGdHpXNC9jYkhwamtITnlRM0FiWXd6NlBV
                MmI5S2sKk0LJtiova6v3buVtZ1cR/i7cGDCT8PS+hLkQF2AFLSzCfCwRWnpQq1F+
                g1y0sAGx+m3LyX3IfHpHUI3lu0xNgvIeVe4cTtpT4WP6VAjtFIEe+nmkqsywDJQy
                bc8xbV72ZaP1lXeQywoR9LqbcCTRJ1xmNeZ2wvN7XoIXDfmj8Alb8kmpmku7Wh3l
                COnfO5oAbuypQ90d1e8Cfui3RB9OA6jgQinGahFYyEWz2CMOVNz3t3hojpreNRSV
                TCW49nr96/wKz0aoMmuyZUeOC0voiFdEIs6YULpnjOeNJdO2DsPJ8PZSRps5z9Oq
                EBkdJiUgIdzb9mhEdrIoy/TdsD5lWAn9NsMc5rPIPWOS6hvzbGPZ/z3yeI7LhcnC
                8gvT0S3f6uDQL6pw+L2uFGE2cO9ddREHQs6SeugquFmOgqi2MrGBcjjcMcIT05oo
                BI9R6iwZhwoNiX2LHH8RpdnOuOcUYaqdR+5kRY7XYMSdhxVLbZIu1A2NHnJqcRb5
                oJypW3TpUp5BCU3Skri6/FEJXSyAJ61qUotfHwyuv7QCmm9y3+ze25HUEi2QMjDf
                yXQ72l2pEoI+BIICl9VDwQw=
                -----END AGE ENCRYPTED FILE-----
            '';
            sha256 = "5f717a2dce022f824b94224b007f80d21ee089de3f1da483a66401848d944029";
        };
    };
    flake.nixosConfigurations.${hostname} = {

    };
}
