# shellcheck shell=bash disable=SC2034 # read by ssm
# THIS WAS WRITTEN BY A CLANKER
# roc app on the builtin platform, nightly zig compiler

ssm_tpl_covers=(.build)

ssm_tpl_flake_inputs=('roc-overlay = { url = "github:roc-lang/roc-overlay"; inputs.nixpkgs.follows = "nixpkgs"; inputs.nixpkgs-darwin.follows = "nixpkgs"; };')
ssm_tpl_flake_overlays=('inputs.roc-overlay.overlays.default')
