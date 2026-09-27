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

    $"(ansi light_magenta)($env.USER)(ansi reset)@(ansi light_blue)($hostname) (ansi light_yellow)($env.PWD)(ansi magenta)($git_prompt)(ansi reset)\n[($user_char)] "
}
$env.PROMPT_INDICATOR = ''
$env.PROMPT_COMMAND_RIGHT = ''
