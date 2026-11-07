# shellcheck shell=bash disable=SC2034 # read by ssm
# THIS WAS WRITTEN BY A CLANKER
# zig cli, dependencies locked with nixpkgs' zon2nix

# prefixes, cache, fetched packages
ssm_tpl_covers=(.build .zig-cache zig-pkg)

# cwd is the staged subproject with the template files overlaid
ssm_tpl_stage() {
    # zig names and fingerprints the package
    local init="../.zig-init/$1" name fingerprint
    { mkdir -p -- "$init" && (cd -- "$init" && zig init --minimal &> /dev/null); } || return 1
    name="$(sed -n 's/^    \.name = \(\.[A-Za-z0-9_]*\),$/\1/p' "$init/build.zig.zon")"
    fingerprint="$(sed -n 's/^    \.fingerprint = \(0x[0-9a-f]*\),.*$/\1/p' "$init/build.zig.zon")"
    rm -rf -- ../.zig-init
    if [[ -z "$name" || -z "$fingerprint" ]]; then
        printErr "zig init didn't generate a package name and fingerprint"
        return 1
    fi
    sed -i "s/^    \.name = .*,\$/    .name = $name,/; s/^    \.fingerprint = 0x0,/    .fingerprint = $fingerprint,/" build.zig.zon \
        || return 1
    bash ./do lock
}
