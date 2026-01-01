# ==============================================================================
# Minimal Environment Variables (loaded in all zsh sessions)
# ==============================================================================

# 🧭 Base paths (XDG-compliant)
export XDG_CONFIG_HOME="${HOME}/.config"
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export CARGO_HOME="${XDG_CONFIG_HOME}/.cargo"
export ZSH_CACHE_DIR="${ZDOTDIR}/cache"

# ==============================================================================
# Terminal Behavior Enhancements (only if interactive)
# ==============================================================================

# 🪟 Set terminal title on each prompt
if [[ -o interactive ]]; then
  _set_terminal_title() {
    print -Pn "\e]0;%n@%m: %~\a"
  }
  precmd_functions+=(_set_terminal_title)
fi
