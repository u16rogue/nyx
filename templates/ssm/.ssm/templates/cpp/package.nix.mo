{ lib, clangStdenv, cmake, ninja, spdlog, ... }: clangStdenv.mkDerivation {
    pname = "{{subproject_name}}";
    version = "{{subproject_version}}";

    # everything the build reads, anything else doesn't exist for it
    src = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [
            ./CMakeLists.txt
            ./do
            ./src
        ];
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
