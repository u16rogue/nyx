# shellcheck shell=bash disable=SC2034 # read by ssm
# rust cli built with cargo, dependencies vendored from Cargo.lock

# cargo's target dir, moved there by .cargo/config.toml
ssm_tpl_covers=(.build)

# cwd is the staged subproject with the template files overlaid
ssm_tpl_stage() {
    # rewrites the shipped Cargo.lock in the format of the devshell's cargo
    bash ./do lock
}
