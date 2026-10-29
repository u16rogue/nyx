**
.*
!.gitignore
!flake.nix
!flake.lock

!.nyx-sbx/
!.nyx-sbx/dev-hook.sh
!.nyx-sbx/share/
!.nyx-sbx/share/**

{{#subprojects}}
!{{.}}/
{{/subprojects}}
