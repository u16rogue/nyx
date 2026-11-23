{
    inputs, lib, pkgs, stdenv, fetchurl,
    opencode, claude-code, ripgrep, wayland, libnotify, coreutils,
    patchelf, makeBinaryWrapper, installShellFiles,
    overridesOpts ? {}, ...
}: let
    setDefault = name: value: /*bash*/ ''
        if [ -z "''${${name}+x}" ]; then export ${name}=${lib.escapeShellArg (builtins.toJSON value)}; fi
    '';

    opencode-release = let
        lock = import ./lock.nix;
        asset = lock.assets.${stdenv.hostPlatform.system}
            or (throw "opencode: lock.nix has no release asset for ${stdenv.hostPlatform.system}");
    in stdenv.mkDerivation {
        pname = "opencode";
        inherit (lock) version;
        src = fetchurl { inherit (asset) url hash; };
        sourceRoot = ".";

        nativeBuildInputs = [ patchelf makeBinaryWrapper installShellFiles ];
        dontConfigure = true;
        dontBuild = true;
        # bun single-file executables keep their bundle appended to the ELF, stripping destroys it
        dontStrip = true;

        # mirrors the wrapper of nixpkgs' opencode
        installPhase = ''
            runHook preInstall
            install -Dm755 opencode $out/bin/opencode
            # only links against glibc, so the interpreter is all that needs fixing
            patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/opencode
            wrapProgram $out/bin/opencode \
                --set OPENCODE_DISABLE_AUTOUPDATE true \
                --suffix PATH : ${lib.makeBinPath [ ripgrep ]} \
                --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ stdenv.cc.cc wayland ]}
            runHook postInstall
        '';

        postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
            # opencode creates $TMPDIR/opencode, which collides with the unpacked binary in the build dir
            export HOME="$(mktemp -d)" TMPDIR="$(mktemp -d)"
            installShellCompletion --cmd opencode \
                --bash <($out/bin/opencode --completions bash) \
                --zsh <($out/bin/opencode --completions zsh) \
                --fish <($out/bin/opencode --completions fish)
        '';

        meta = {
            inherit (opencode.meta) description homepage license;
            changelog = "https://github.com/anomalyco/opencode/releases/tag/v${lock.version}";
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            platforms = builtins.attrNames lock.assets;
            mainProgram = "opencode";
        };
    };

    source = overridesOpts.source or "release";
    base = {
        release = opencode-release;
        nixpkgs = opencode;
    }.${source} or (throw "opencode: unknown overridesOpts.source '${source}', expected \"release\" or \"nixpkgs\"");

    claude = lib.getExe claude-code;
in inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = base;
    preHook = lib.concatStrings [
        ''
            if [ -z "''${OPENCODE_CLAUDE_PATH+x}" ]; then export OPENCODE_CLAUDE_PATH=${lib.escapeShellArg claude}; fi
            # opencode only finds themes in the themes directory of its config dir, the built-in catppuccin
            # paints the main background which covers the terminal's background opacity
            themes_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/opencode/themes"
            ${coreutils}/bin/mkdir -p "$themes_dir" 2> /dev/null \
                && ${coreutils}/bin/ln -sfnT ${./nyx-catppuccin.json} "$themes_dir/nyx-catppuccin.json" 2> /dev/null \
                || true
        ''
        (setDefault "OPENCODE_CONFIG_CONTENT" {
            permissions = [
                { action = "external_directory"; resource = "/nix/store/*"; effect = "allow"; }
                { action = "read"; resource = "/nix/store/*"; effect = "allow"; }
                { action = "edit"; resource = "/nix/store/*"; effect = "deny"; }
            ];
        })
        (setDefault "OPENCODE_CLI_CONFIG_CONTENT" {
            theme.name = "nyx-catppuccin";
            attention.notifications = false;
            plugins = [
                "${./nyx-connect-claude}"
                "${./nyx-erm}"
                { package = "${./nyx-notify}"; options.notify_send = "${libnotify}/bin/notify-send"; }
                "${./nyx-openrouter-tracker}"
            ];
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
