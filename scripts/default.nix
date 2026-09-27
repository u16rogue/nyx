{ lib, ... }: {
    perSystem = { pkgs, ... }:
    let
        writeNuShellApplication = { name, text, runtimeInputs ? [], meta ? {} }:
            let
                runtimeBinPath = lib.makeBinPath runtimeInputs;
            in pkgs.runCommand name {
                inherit meta;
                nativeBuildInputs = [ pkgs.makeWrapper ];
            } ''
                mkdir -p "$out/bin" "$out/share/nushell/modules" "$out/share/nushell/vendor/autoload"
                cp ${pkgs.writeText "${name}.nu" text} "$out/share/nushell/modules/${name}.nu"
                ${lib.optionalString (runtimeInputs != []) ''
                    printf '%s\n' ${lib.escapeShellArg "$env.PATH = (('${runtimeBinPath}' | split row (char esep)) ++ $env.PATH)"} \
                        > "$out/share/nushell/vendor/autoload/${name}.nu"
                ''}
                printf 'use %s *\n' "$out/share/nushell/modules/${name}.nu" \
                    >> "$out/share/nushell/vendor/autoload/${name}.nu"
                makeWrapper ${pkgs.nushell}/bin/nu "$out/bin/${name}" \
                    --add-flags "$out/share/nushell/modules/${name}.nu" ${lib.optionalString (runtimeInputs != []) "--prefix PATH : ${lib.escapeShellArg runtimeBinPath}"}
            ''
        ;
    in {
        packages = (lib.pipe (builtins.readDir ./.) [
            (lib.filterAttrs (filename: filetype: (filetype == "directory" && builtins.pathExists (./. + "/${filename}/package.nix"))))
            (lib.mapAttrs (filename: filetype: (
                pkgs.callPackage (./. + "/${filename}/package.nix") {
                    inherit writeNuShellApplication;
                }
            )))
        ]);
    };
}
