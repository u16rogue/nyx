# shellcheck shell=bash disable=SC2034 # read by ssm
# c++23 cli, cmake + ninja + clang, spdlog from nixpkgs

# build trees and installs, clangd's index
ssm_tpl_covers=(.build .cache)
