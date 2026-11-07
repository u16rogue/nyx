{{! THIS WAS WRITTEN BY A CLANKER }}
{ lib, stdenvNoCC, rocpkgs, ... }: stdenvNoCC.mkDerivation {
    pname = "{{subproject_name}}";
    version = "{{subproject_version}}";

    # local builds would clash
    src = lib.cleanSourceWith {
        src = ./.;
        filter = path: _: baseNameOf path != ".build";
    };

    nativeBuildInputs = [
        rocpkgs.nightly
    ];

    # roc caches into $HOME
    preBuild = ''
        export ROC_CACHE_DIR="$TMPDIR/roc"
    '';

    buildPhase = ''
        runHook preBuild
        bash ./do build-release
        runHook postBuild
    '';

    installPhase = ''
        runHook preInstall
        install -Dm755 -t "$out/bin" .build/release/{{subproject_name}}
        runHook postInstall
    '';

    meta = {
        description = "";
        mainProgram = "{{subproject_name}}";
        platforms = lib.platforms.linux;
    };
}
