{{! THIS WAS WRITTEN BY A CLANKER: ignores for rg/fd (telescope live_grep/find_files), unlike .gitignore this hides generated/vendored files while leaving untracked personal files searchable }}
.git/
.ssm/
.ssm-stage/
.direnv/
result
result-*

# js (bun, sveltekit)
node_modules/
.svelte-kit/
dist/
build/

# c/c++ (cmake build dirs, clangd index)
.cache/

# zig
zig-out/
.zig-cache/
zig-cache/

# rust
target/

# python
__pycache__/
.venv/
