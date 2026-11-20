{ lib, stdenvNoCC, rocpkgs, ... }: stdenvNoCC.mkDerivation {
    pname = "{{subproject_name}}";
    version = "{{subproject_version}}";

    # everything the build reads, anything else doesn't exist for it
    src = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [
            ./do
            ./main.roc
        ];
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
