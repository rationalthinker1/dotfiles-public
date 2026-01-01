# ==============================================================================
# Minimal Environment Variables (loaded in all zsh sessions)
# ==============================================================================
# NOTE: This file runs for ALL shells (interactive and non-interactive)
# Only put environment variables here, NO interactive logic

# 🧭 Base paths (XDG-compliant)
export XDG_CONFIG_HOME="${HOME}/.config"
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export CARGO_HOME="${XDG_CONFIG_HOME}/.cargo"
export ZSH_CACHE_DIR="${ZDOTDIR}/cache"
