# THIS WAS WRITTEN BY A CLANKER
{
    # Forgejo served by the `svc-traefik` module at `url`.
    # Git over SSH goes through the system sshd: `forgejo@<url host>:<owner>/<repo>.git`.
    flake.modules.nixos.svc-forgejo = { config, lib, ... }: let
        # The only thing to change when the address changes (eg. `https://git.example.com`).
        # Forgejo has to know its public URL (links, clone URLs, redirects), everything else is derived.
        url = "http://${config.networking.hostName}.local/git";
        port = 3000;

        parsed = lib.throwIf (builtins.match pattern url == null)
            "the `svc-forgejo` module url '${url}' must look like `http(s)://<host>[/<path>]`."
            (builtins.match pattern url);
        pattern = "(https?)://([^/:]+)(/.*[^/])?/?";
        scheme = builtins.elemAt parsed 0;
        domain = builtins.elemAt parsed 1;
        subpath = lib.defaultTo "" (builtins.elemAt parsed 2);
    in {
        services.forgejo = {
            enable = true;
            settings = {
                server = {
                    DOMAIN = domain;
                    ROOT_URL = "${scheme}://${domain}${subpath}/";
                    HTTP_ADDR = "127.0.0.1";
                    HTTP_PORT = port;
                };
                session.COOKIE_SECURE = scheme == "https";
                # Accounts are created with `forgejo admin user create`
                service.DISABLE_REGISTRATION = true;
            };
        };

        # For the `forgejo admin` CLI
        environment.systemPackages = [ config.services.forgejo.package ];

        services.traefik.dynamicConfigOptions.http = {
            routers.forgejo = {
                entryPoints = [ (if scheme == "https" then "websecure" else "web") ];
                # Matched on the path only so the host is also reachable by IP (the Host header is then the IP, not `domain`)
                rule = if subpath != "" then "Path(`${subpath}`) || PathPrefix(`${subpath}/`)" else "PathPrefix(`/`)";
                middlewares = lib.optional (subpath != "") "forgejo-strip-prefix";
                service = "forgejo";
            };
            middlewares = lib.optionalAttrs (subpath != "") {
                forgejo-strip-prefix.stripPrefix.prefixes = [ subpath ];
            };
            services.forgejo.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString port}"; }];
        };

        assertions = [
            {
                assertion = config.services.traefik.enable;
                message = "the `svc-forgejo` module is only reachable through the `svc-traefik` module, import it as well.";
            }
            {
                assertion = config.services.openssh.enable;
                message = "the `svc-forgejo` module serves git over the system sshd, import the `ssh-server` module as well.";
            }
        ];
    };
}
