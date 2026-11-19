**
.*
!/.gitignore
!/flake.nix
!/flake.lock
!/AGENTS.md
!/.jj.toml

!/clanker-ref/
!/clanker-ref/**/
!/clanker-ref/**/*.md

!/.nyx-sbx/
!/.nyx-sbx/dev-hook.sh
!/.nyx-sbx/share/

!/scripts/

!/.ignore
!/.nvim.lua
!/.nvim/
!/.nvim/snippets/
!/.nvim/snippets/*.json

{{#subprojects}}
!/{{.}}/
{{/subprojects}}
