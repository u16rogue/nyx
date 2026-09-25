if set -q XDG_RUNTIME_DIR
    set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/gnupg/S.gpg-agent.ssh"
end

if status is-interactive
    set -g fish_greeting
    set -gx GPG_TTY (tty)
    fish_config theme choose default --no-override
    fish_vi_key_bindings
end

function fish_prompt
    set -l user_char '$'
    if fish_is_root_user
        set user_char '#'
    end
    set -l git_prompt (fish_git_prompt)
    if test "$git_prompt" = ""
        set git_prompt ''
    end
    printf '%s%s%s@%s%s %s%s%s%s%s\n[%s] ' \
        (set_color brmagenta) $USER        \
        (set_color normal)                 \
        (set_color brblue) $hostname       \
        (set_color bryellow) (pwd)         \
        (set_color magenta)  $git_prompt   \
        (set_color normal) $user_char
end
