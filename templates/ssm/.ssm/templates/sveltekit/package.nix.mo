{{! CLANKER EDITED: the `build` config picks the ./do command and its adapter options, $out is laid out here, meta set through overrideAttrs }}
{ lib, bun2nix, bun, makeWrapper, ... }: let
    build = {
        mode = "bundle";
        bytecode = true;
        aot = false;
        trim = false;
    };
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

    # read by ./do build-compile
    env.ADAPTER_BUILD_OPTIONS = builtins.toJSON {
        inherit (build) bytecode;
        compile = { inherit (build) aot trim; };
    };

    preBuild = ''
    '';

    buildPhase = ''
        runHook preBuild
        bash ./do build-${build.mode}
        runHook postBuild
    '';

    # compile: the adapter's server executable. bundle: the adapter output in share/ with its
    # production dependencies (only `dependencies` aren't bundled) and a bun wrapper
    installPhase = ''
        runHook preInstall
    '' + (if build.mode == "compile" then ''
        install -Dm755 .build/compile/server "$out/bin/{{subproject_name}}"
    '' else ''
        share="$out/share/{{subproject_name}}"
        mkdir -p "$share"
        cp -r .build/bundle "$share/build"
        cp package.json bun.lock "$share/"
        if bun -e 'process.exit(Object.keys(require("./package.json").dependencies ?? {}).length ? 0 : 1)'; then
            (cd "$share" && bun install --production --frozen-lockfile --ignore-scripts)
        fi
        makeWrapper ${lib.getExe bun} "$out/bin/{{subproject_name}}" --add-flags "$share/build"
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
