{ lib, stdenvNoCC, ... }: stdenvNoCC.mkDerivation {
    pname = "{{subproject_name}}";
    version = "{{subproject_version}}";

    # everything the build reads, anything else doesn't exist for it
    src = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [
        ];
    };

    nativeBuildInputs = [
    ];

    preBuild = ''
    '';

    buildPhase = ''
        runHook preBuild
        runHook postBuild
    '';

    installPhase = ''
        runHook preInstall
        runHook postInstall
    '';

    meta = {
        description = "";
        mainProgram = "";
        platforms = lib.platforms.linux;
    };
}
