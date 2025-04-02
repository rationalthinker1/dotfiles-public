export XDG_CONFIG_HOME="${HOME}/.config"
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export CARGO_HOME="${XDG_CONFIG_HOME}/.cargo"

if [[ -s "${ZDOTDIR}/.zshrc.zwc" && "${ZDOTDIR}/.zshrc.zwc" -nt "${ZDOTDIR}/.zshrc" ]]; then
    source "${ZDOTDIR}/.zshrc.zwc"
else
    source "${ZDOTDIR}/.zshrc"
fi

. "${CARGO_HOME}/env"
