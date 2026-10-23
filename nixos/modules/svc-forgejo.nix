# THIS WAS WRITTEN BY A CLANKER
{
    # Forgejo listening on `<listen.address>:<listen.port>` (localhost by default); exposing it at `url` is up to the host.
    # Git over SSH goes through the system sshd: `forgejo@<url host>:<owner>/<repo>.git`.
    flake.modules.nixos.svc-forgejo = { config, lib, ... }: let
        cfg = config.nyxos.svc-forgejo;

        pattern = "(https?)://([^/:]+)(/.*[^/])?/?";
        parsed = builtins.match pattern cfg.url;
        scheme = builtins.elemAt parsed 0;
        domain = builtins.elemAt parsed 1;
        subpath = lib.defaultTo "" (builtins.elemAt parsed 2);
    in {
        options.nyxos.svc-forgejo = {
            # Forgejo has to know its public URL (links, clone URLs, redirects).
            url = lib.mkOption {
                description = "Public URL Forgejo is reached at, `http(s)://<host>[/<path>]`.";
                type = lib.types.strMatching pattern;
                example = "https://git.example.com";
            };
            listen.address = lib.mkOption {
                description = "Address Forgejo binds to. Anything but localhost also needs the port opened in the firewall.";
                type = lib.types.str;
                default = "127.0.0.1";
            };
            listen.port = lib.mkOption {
                description = "Port Forgejo listens on.";
                type = lib.types.port;
                default = 3000;
            };
        };

        config = {
            services.forgejo = {
                enable = true;
                settings = {
                    server = {
                        DOMAIN = domain;
                        ROOT_URL = "${scheme}://${domain}${subpath}/";
                        HTTP_ADDR = cfg.listen.address;
                        HTTP_PORT = cfg.listen.port;
                    };
                    session.COOKIE_SECURE = scheme == "https";
                    # Accounts are created with `forgejo admin user create`
                    service.DISABLE_REGISTRATION = true;
                    # Actions is opt-in: new repos start without it (Forgejo's default list minus `repo.actions`)
                    repository.DEFAULT_REPO_UNITS = lib.concatStringsSep "," [
                        "repo.code" "repo.releases" "repo.issues" "repo.pulls" "repo.wiki" "repo.projects" "repo.packages"
                    ];
                };
            };

            # For the `forgejo admin` CLI
            environment.systemPackages = [ config.services.forgejo.package ];

            assertions = [{
                assertion = config.services.openssh.enable;
                message = "the `svc-forgejo` module serves git over the system sshd, import the `ssh-server` module as well.";
            }];
        };
    };
}
