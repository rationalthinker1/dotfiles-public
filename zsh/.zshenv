export XDG_CONFIG_HOME="${HOME}/.config"
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export CARGO_HOME="${XDG_CONFIG_HOME}/.cargo"
export ZSH_CACHE_DIR="${ZDOTDIR}/cache"

if [[ -s "${ZDOTDIR}/.zshrc.zwc" && "${ZDOTDIR}/.zshrc.zwc" -nt "${ZDOTDIR}/.zshrc" ]]; then
    source "${ZDOTDIR}/.zshrc.zwc"
else
    source "${ZDOTDIR}/.zshrc"
fi

# Optional terminal enhancements
# Set terminal title
precmd() {
  print -Pn "\e]0;%n@%m: %~\a"
}

# compinit with cache and ignore insecure files
if [[ -n "$ZSH_CACHE_DIR" ]]; then
  mkdir -p "$ZSH_CACHE_DIR"
  autoload -Uz compinit
  compinit -i -d "$ZSH_CACHE_DIR/zcompdump-${HOST_OS:-default}"
else
  autoload -Uz compinit
  compinit -i
fi


. "${CARGO_HOME}/env"
