{ lib, stdenv, stdenvNoCC, fetchurl, autoPatchelfHook, makeWrapper, ripgrep, ... }: stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "opencode";
    version = "2.0.22";

    src = fetchurl {
        url = "https://registry.npmjs.org/@opencode/cli-linux-x64-baseline/-/cli-linux-x64-baseline-${finalAttrs.version}.tgz";
        hash = "sha512-nwVyjnug68v1A0emkDf28GUM37m5PjiFgu2Xbn3ujNHdnSd0v43Yr5G7TD1XTvAbXg+Zv46hX0CvINJorLuOFA==";
    };

    nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
    buildInputs = [ stdenv.cc.cc.lib ];

    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;

    installPhase = /*bash*/ ''
        runHook preInstall
        install -Dm755 bin/opencode "$out/bin/opencode"
        wrapProgram "$out/bin/opencode" \
            --prefix PATH : ${lib.makeBinPath [ ripgrep ]} \
            --set OPENCODE_DISABLE_AUTOUPDATE true
        runHook postInstall
    '';

    meta = {
        description = "OpenCode v2 AI coding agent (pinned upstream binary)";
        homepage = "https://opencode.ai/v2/docs";
        license = lib.licenses.mit;
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        platforms = [ "x86_64-linux" ];
        mainProgram = "opencode";
    };
})
