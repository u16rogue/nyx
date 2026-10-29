{ lib, stdenvNoCC, ... }: stdenvNoCC.mkDerivation {
    pname = "{{subproject_name}}";
    version = "{{subproject_version}}";
 
    src = ./.;
 
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
