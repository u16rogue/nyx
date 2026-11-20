{ lib, stdenvNoCC, makeWrapper, lua5_4, ... }: let
    # runtime lua and its rocks, add dependencies here (eg. `ps: with ps; [ luafilesystem ]`)
    lua = lua5_4.withPackages (ps: []);
in stdenvNoCC.mkDerivation {
    pname = "{{subproject_name}}";
    version = "{{subproject_version}}";

    # everything the build reads, anything else doesn't exist for it
    src = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [
            ./do
            ./tlconfig.lua
            ./src
        ];
    };

    nativeBuildInputs = [
        makeWrapper
        lua
        lua5_4.pkgs.tl
        lua5_4.pkgs.cyan
    ];

    preBuild = ''
    '';

    buildPhase = ''
        runHook preBuild
        bash ./do build-release
        runHook postBuild
    '';

    installPhase = ''
        runHook preInstall
        mkdir -p "$out/share/{{subproject_name}}"
        cp -a .build/lua/. "$out/share/{{subproject_name}}"
        makeWrapper ${lua}/bin/lua "$out/bin/{{subproject_name}}" \
            --prefix LUA_PATH ";" "$out/share/{{subproject_name}}/?.lua;$out/share/{{subproject_name}}/?/init.lua" \
            --add-flags "$out/share/{{subproject_name}}/main.lua"
        runHook postInstall
    '';

    meta = {
        description = "";
        mainProgram = "{{subproject_name}}";
        platforms = lib.platforms.linux;
    };
}
