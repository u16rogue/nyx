{ inputs, pkgs, zellij, ... }: inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = zellij;
    env.ZELLIJ_CONFIG_DIR = "${./config}";
    env.ZELLIJ_CONFIG_FILE = "${./config}/config.kdl";
}
