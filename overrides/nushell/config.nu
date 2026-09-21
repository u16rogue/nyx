$env.config.show_banner = false
$env.config.edit_mode = 'vi'

if "XDG_RUNTIME_DIR" in $env {
    $env.SSH_AUTH_SOCK = ($env.XDG_RUNTIME_DIR | path join "gnupg" "S.gpg-agent.ssh")
}
if $nu.is-interactive {
    $env.GPG_TTY = (tty | str trim)
}
