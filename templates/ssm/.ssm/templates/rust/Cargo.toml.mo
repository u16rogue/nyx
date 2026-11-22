[package]
name = "{{subproject_name}}"
version = "{{subproject_version}}"
edition = "2024"

# run `./do lock` after changing these, package.nix reads Cargo.lock
[dependencies]

[lints.clippy]
all = { level = "warn", priority = -1 }
