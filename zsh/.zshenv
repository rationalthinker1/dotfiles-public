# ==============================================================================
# Minimal Environment Variables (loaded in all zsh sessions)
# ==============================================================================

# 🧭 Base paths (XDG-compliant)
export XDG_CONFIG_HOME="${HOME}/.config"
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export CARGO_HOME="${XDG_CONFIG_HOME}/.cargo"
export ZSH_CACHE_DIR="${ZDOTDIR}/cache"

# ==============================================================================
# Load Compiled or Fallback .zshrc
# ==============================================================================

# if [[ -s "${ZDOTDIR}/.zshrc.zwc" && "${ZDOTDIR}/.zshrc.zwc" -nt "${ZDOTDIR}/.zshrc" ]]; then
#   source "${ZDOTDIR}/.zshrc.zwc"
# else
#   source "${ZDOTDIR}/.zshrc"
# fi

# ==============================================================================
# Terminal Behavior Enhancements (only if interactive)
# ==============================================================================

# 🪟 Set terminal title on each prompt
if [[ -o interactive ]]; then
  precmd() {
    print -Pn "\e]0;%n@%m: %~\a"
  }
fi

# ==============================================================================
# Rust Environment
# ==============================================================================

# 🦀 Load cargo env (if present)
# NOTE: Commented out for performance - Cargo bin path is added in .zshrc via add_to_path_if_exists
# [[ -f "${CARGO_HOME}/env" ]] && source "${CARGO_HOME}/env"
