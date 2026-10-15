#!/usr/bin/env bash

if (( $# == 0 )) && command -v zellij &>/dev/null; then
    zellij_args=()
    if [[ -f "$PWD/.nyx-sbx/zellij.kdl" ]]; then
        zellij_args+=(--layout "$PWD/.nyx-sbx/zellij.kdl")
    fi
    # Zellij 0.44 otherwise resurrects the old layout for this session.
    previous_session="${XDG_CACHE_HOME:-$HOME/.cache}/zellij/contract_version_1/session_info/main"
    if [[ -d "$previous_session" ]] && ! rm -rf -- "$previous_session"; then
        echo "[warn] failed to remove previous Zellij session" >&2
    fi
    exec zellij --layout "$PWD/.nyx-sbx/zellij.kdl" attach --create main
fi
