{ lib, stdenv, stdenvNoCC, fetchurl, autoPatchelfHook, makeWrapper, ripgrep, ... }: stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "opencode";
    version = "2.0.26";

    src = fetchurl {
        url = "https://registry.npmjs.org/@opencode/cli-linux-x64-baseline/-/cli-linux-x64-baseline-${finalAttrs.version}.tgz";
        hash = "sha512-A+OonlFxNQh4xh/dI/YcDQlG+iiRhnIMTakSsavIyUuHvKo0hIrTUuwGSzSmspS+22QYrxqKTQ7bmF7jJvGwGQ==";
    };

    nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
    buildInputs = [ stdenv.cc.cc.lib ];

    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;

    installPhase = /*bash*/ ''
        runHook preInstall
        install -Dm755 bin/opencode "$out/bin/opencode"
        wrapProgram "$out/bin/opencode" \
            --prefix PATH : ${lib.makeBinPath [ ripgrep ]} \
            --set OPENCODE_DISABLE_AUTOUPDATE true \
            --set-default OPENCODE_CONFIG_CONTENT ${lib.escapeShellArg (builtins.toJSON {
                permissions = [
                    { action = "external_directory"; resource = "/nix/store/*"; effect = "allow"; }
                    { action = "read"; resource = "/nix/store/*"; effect = "allow"; }
                    { action = "edit"; resource = "/nix/store/*"; effect = "deny"; }
                ];
            })} \
            --set-default OPENCODE_CLI_CONFIG_CONTENT ${lib.escapeShellArg (builtins.toJSON {
                theme.name = "catppuccin";
                keybinds = {
                    leader = "space";
                    "input.delete.word.backward" = "ctrl+backspace,alt+backspace";
                    "session.tab.previous" = "alt+z";
                    "session.tab.next" = "alt+x";
                    "session.tab.close" = "alt+c";
                    "session.list" = "<leader>f";
                };
            })}
        runHook postInstall
    '';

    meta = {
        description = "OpenCode v2 AI coding agent (pinned upstream binary)";
        homepage = "https://opencode.ai/v2/docs";
        license = lib.licenses.mit;
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        platforms = [ "x86_64-linux" ];
        mainProgram = "opencode";
    };
})
