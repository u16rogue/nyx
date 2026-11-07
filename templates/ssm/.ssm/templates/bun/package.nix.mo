{{! CLANKER EDITED: the `build` config picks the ./do command and its flags, $out is laid out here, meta set through overrideAttrs }}
{ lib, bun2nix, bun, makeWrapper, ... }: let
    build = {
        mode = "bundle";
        bytecode = true;
        aot = false;
        trim = false;
    };
    flags = lib.optionals (build.mode == "compile") (
        lib.optional build.bytecode "--bytecode"
        ++ lib.optional build.aot "--aot"
        ++ lib.optional build.trim "--trim"
    );
in
(bun2nix.mkDerivation {
    pname = "{{subproject_name}}";
    version = "{{subproject_version}}";

    bunDeps = bun2nix.fetchBunDeps {
        bunNix = ./bun.lock.nix;
    };

    src = ./.;

    # postinstall regenerates bun.lock.nix, which is pointless inside the sandbox
    dontRunLifecycleScripts = true;

    # fixup breaks compiled executables
    dontFixup = build.mode == "compile";

    nativeBuildInputs = [
        bun
        makeWrapper
    ];

    preBuild = ''
    '';

    buildPhase = ''
        runHook preBuild
        bash ./do build-${build.mode} ${lib.escapeShellArgs flags}
        runHook postBuild
    '';

    # compile: the executable, its sourcemap is embedded. bundle: the script in share/ with a bun wrapper
    installPhase = ''
        runHook preInstall
    '' + (if build.mode == "compile" then ''
        install -Dm755 -t "$out/bin" .build/compile/{{subproject_name}}
    '' else ''
        mkdir -p "$out/share"
        cp -r .build/bundle "$out/share/{{subproject_name}}"
        makeWrapper ${lib.getExe bun} "$out/bin/{{subproject_name}}" --add-flags "$out/share/{{subproject_name}}/{{subproject_name}}.js"
    '') + ''
        runHook postInstall
    '';
}).overrideAttrs (prev: {
    # bun2nix overwrites meta
    meta = prev.meta // {
        description = "";
        platforms = lib.platforms.linux;
    };
})
