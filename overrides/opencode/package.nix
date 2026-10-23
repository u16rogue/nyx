{ inputs, lib, pkgs, opencode, ... }: let
    setDefault = name: value: /*bash*/ ''
        if [ -z "''${${name}+x}" ]; then export ${name}=${lib.escapeShellArg (builtins.toJSON value)}; fi
    '';
in inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = opencode;
    preHook = lib.concatStrings [
        (setDefault "OPENCODE_CONFIG_CONTENT" {
            permissions = [
                { action = "external_directory"; resource = "/nix/store/*"; effect = "allow"; }
                { action = "read"; resource = "/nix/store/*"; effect = "allow"; }
                { action = "edit"; resource = "/nix/store/*"; effect = "deny"; }
            ];
        })
        (setDefault "OPENCODE_CLI_CONFIG_CONTENT" {
            theme.name = "catppuccin";
            keybinds = {
                leader = "ctrl+space";
                "input.delete.word.backward" = "ctrl+backspace,alt+backspace";
                "session.tab.previous" = "alt+z";
                "session.tab.next" = "alt+x";
                "session.tab.close" = "alt+c";
                "session.list" = "<leader>f";
            };
        })
    ];
}
