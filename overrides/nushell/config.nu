$env.config.show_banner = false
$env.config.edit_mode = 'vi'

$env.config.history.file_format = "sqlite"
$env.config.history.isolation = true

$env.config.completions.algorithm = "substring"
$env.config.completions.quick = true

let fish_completer = {|spans|
    fish --no-config --command $"complete '--do-complete=($spans | str replace --all "'" "\\'" | str join ' ')'"
    | from tsv --flexible --noheaders --no-infer
    | rename value description
    | update value {|row|
        let value = $row.value
        let need_quote = ['\' ',' '[' ']' '(' ')' ' ' '\t' "'" '"' "`"] | any {$in in $value}
        if ($need_quote and ($value | path exists)) {
            let expanded_path = if ($value starts-with ~) {$value | path expand --no-symlink} else {$value}
            $'"($expanded_path | str replace --all "\"" "\\\"")"'
        } else {$value}
    }
}

$env.config.completions.external = {
    enable: true
    completer: $fish_completer
}

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
