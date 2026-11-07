{{! THIS WAS WRITTEN BY A CLANKER }}
{ lib, clangStdenv, cmake, ninja, spdlog, ... }: clangStdenv.mkDerivation {
    pname = "{{subproject_name}}";
    version = "{{subproject_version}}";

    # a local build tree would clash with the sandbox's
    src = lib.cleanSourceWith {
        src = ./.;
        filter = path: _: !(lib.elem (baseNameOf path) [ ".build" ".cache" ]);
    };

    nativeBuildInputs = [
        cmake
        ninja
    ];

    buildInputs = [
        spdlog
    ];

    # ./do configures
    dontUseCmakeConfigure = true;

    buildPhase = ''
        runHook preBuild
        bash ./do build-release
        runHook postBuild
    '';

    # by the install() rules in CMakeLists.txt
    installPhase = ''
        runHook preInstall
        cmake --install .build/release --prefix "$out"
        runHook postInstall
    '';

    meta = {
        description = "";
        mainProgram = "{{subproject_name}}";
        platforms = lib.platforms.linux;
    };
}
