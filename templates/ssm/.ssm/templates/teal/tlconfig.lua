-- THIS WAS WRITTEN BY A CLANKER
-- read by cyan (./do) and teal-language-server
return {
    source_dir = "src",
    build_dir = ".build/lua",
    -- runs on package.nix's lua 5.4, teal-language-server doesn't accept "5.4" (yet)
    gen_target = "5.3",
    -- no compat-53 shims needed
    gen_compat = "off",
}
