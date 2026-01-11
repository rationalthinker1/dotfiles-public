#!/usr/bin/env zsh
# ==============================================================================
# .zshenv - Environment Variables (Runs for ALL shells)
# ==============================================================================
# This file runs for EVERY zsh invocation (interactive, non-interactive, scripts)
#
# LOAD ORDER:
#   1. .zshenv     ← YOU ARE HERE (environment variables)
#   2. .zprofile   (login shells only)
#   3. .zshrc      (interactive shells only)
#   4. .zlogin     (after .zshrc in login shells)
#
# USE THIS FILE FOR:
# - Environment variables (PATH, EDITOR, XDG_* paths)
# - Variables needed by scripts and non-interactive shells
# - OS detection that all contexts need
#
# DO NOT PUT HERE:
# - Aliases (→ .zshrc or aliases.zsh)
# - Functions (→ .zshrc or aliases.zsh)
# - Interactive-only config (prompt, plugins → .zshrc)
# ==============================================================================

# Guard for .zshrc fallback sourcing
export ZSHENV_LOADED=1

# 🧭 Base paths (XDG-compliant)
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}"
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export ZSH_CACHE_DIR="${ZDOTDIR}/cache"

# 🧠 Shell and runtime config
export ZSH="${ZDOTDIR}"
export LOCAL_CONFIG="${XDG_CONFIG_HOME}"

# 🧰 Tool-specific envs
export ADOTDIR="${ZDOTDIR}/antigen"
export ENHANCD_DIR="${XDG_CONFIG_HOME}/enhancd"
export RUSTUP_HOME="${XDG_CONFIG_HOME}/.rustup"
export CARGO_HOME="${XDG_CONFIG_HOME}/.cargo"
export VOLTA_HOME="${XDG_CONFIG_HOME}/volta"
export BUN_INSTALL="${XDG_CONFIG_HOME}/bun"
export PNPM_HOME="${XDG_CONFIG_HOME}/pnpm"

# 🖥️ Terminal & editor defaults
export EDITOR="vim"
export LESS="-XRF"

# ☁️ AWS
export AWS_CONFIG_FILE="${XDG_CONFIG_HOME}/.aws/config"
export AWS_SHARED_CREDENTIALS_FILE="${XDG_CONFIG_HOME}/.aws/credentials"

# ==============================================================================
# Detect Host OS & Environment
# ==============================================================================
if [[ -f "${ZDOTDIR}/functions/detect_os.sh" ]]; then
  source "${ZDOTDIR}/functions/detect_os.sh"
fi

# ==============================================================================
# Update PATH
# ==============================================================================
typeset -gU path PATH
path=(
  "${CARGO_HOME}/bin"
  "${HOME}/.local/bin"
  "/usr/local/go/bin"
  "${HOME}/.yarn/bin"
  "${XDG_CONFIG_HOME}/yarn/global/node_modules/.bin"
  "${BUN_INSTALL}/bin"
  "${PNPM_HOME}/bin"
  $path
)

if [[ "${HOST_OS:-}" == "wsl" ]]; then
  # Filter Windows PATH to only essential directories (performance optimization)
  # WSL automatically appends Windows PATH, but it includes 20+ slow NTFS-mounted dirs
  # This causes severe slowdown in fast-syntax-highlighting and other command lookups

  # Build filtered Windows PATH with only essential tools
  typeset -a windows_paths=(
    "/mnt/c/Program Files/PowerShell/7"
    "/mnt/c/Windows/System32"
    "/mnt/c/Windows"
  )

  # Deduplicate and filter PATH: keep Linux paths, add only essential Windows paths
  # This reduces PATH from 30+ entries to ~15, dramatically improving performance
  typeset -U path  # Remove duplicates
  path=(
    ${windows_paths[@]}
    ${path:#/mnt/c/*}  # Remove ALL Windows paths first
  )
fi

# ==============================================================================
# WSL-Specific Settings
# ==============================================================================
if [[ "${HOST_OS:-}" == "wsl" ]]; then
  export LIBGL_ALWAYS_INDIRECT=1
  export BROWSER="wslview"
fi
