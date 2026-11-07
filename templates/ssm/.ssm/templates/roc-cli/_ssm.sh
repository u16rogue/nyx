# shellcheck shell=bash disable=SC2034 # read by ssm
# THIS WAS WRITTEN BY A CLANKER
# roc cli on basic-cli, nightly zig compiler

ssm_tpl_covers=(.build)

ssm_tpl_flake_inputs=('roc-overlay = { url = "github:roc-lang/roc-overlay"; inputs.nixpkgs.follows = "nixpkgs"; inputs.nixpkgs-darwin.follows = "nixpkgs"; };')
ssm_tpl_flake_overlays=('inputs.roc-overlay.overlays.default')

# cwd is the staged subproject with the template files overlaid
ssm_tpl_stage() {
    bash ./do lock
}
