$env.config.show_banner = false
$env.config.edit_mode = 'vi'

if "XDG_RUNTIME_DIR" in $env {
    $env.SSH_AUTH_SOCK = ($env.XDG_RUNTIME_DIR | path join "gnupg" "S.gpg-agent.ssh")
}

if $nu.is-interactive {
    $env.GPG_TTY = (tty | str trim)
}

$env.PROMPT_COMMAND = {||
    let user_char = if $env.USER == 'root' { '#' } else { '$' }
    let hostname = (hostname | str trim)
    let sbx_label = if ("NYX_SBX_ID" in $env) and (($env.NYX_SBX_ID | str trim) != '') {
        $" (ansi light_cyan)[sbx:($env.NYX_SBX_ID)](ansi reset)"
    } else {
        ''
    }
    let nix_label = if ("IN_NIX_SHELL" in $env) or ("NIX_FRAGMENT" in $env) {
        let fragment = ($env.NIX_FRAGMENT? | default '' | str trim)
        let suffix = if $fragment != '' { $":($fragment)" } else { '' }
        $" (ansi light_green)[nix-shell($suffix)](ansi reset)"
    } else {
        ''
    }
    let branch = (git branch --show-current | complete)
    let git_prompt = if $branch.exit_code == 0 {
        let name = ($branch.stdout | str trim)
        let name = if $name == '' {
            (git rev-parse --short HEAD | str trim)
        } else {
            $name
        }
        ' (' + $name + ')'
    } else {
        ''
    }

    $"(ansi light_magenta)($env.USER)(ansi reset)@(ansi light_blue)($hostname)($sbx_label)($nix_label) (ansi light_yellow)($env.PWD)(ansi magenta)($git_prompt)(ansi reset)\n[($user_char)] "
}
$env.PROMPT_INDICATOR = ''
$env.PROMPT_COMMAND_RIGHT = ''
