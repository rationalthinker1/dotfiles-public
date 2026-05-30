function ls --description 'eza-powered ls'
    if not status is-interactive; or not command -q eza
        command ls --color=auto $argv
        return
    end
    eza --color=auto $argv
end
