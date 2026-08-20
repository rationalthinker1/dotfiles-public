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
export DOTFILES_ROOT="${HOME}/.dotfiles"
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
export CLAUDE_CONFIG_DIR="${XDG_CONFIG_HOME}/claude"
export CODEX_HOME="${XDG_CONFIG_HOME}/codex"
export GNUPGHOME="${XDG_CONFIG_HOME}/gnupg"
export PASSWORD_STORE_DIR="${XDG_CONFIG_HOME}/password-store"
export FNM_PATH="${XDG_CONFIG_HOME}/.fnm"

# 🖥️ Terminal & editor defaults
export EDITOR="vim"
export LESS="-XRF"

# 🛠️ Vim build configuration for mise (ASDF_VIM_CONFIG) lives in the [env] block of
# mise/config.toml. It was here once, computing the flags with two python3 spawns on
# EVERY zsh invocation (including scripts); then in a mise() wrapper in aliases.zsh,
# which interactive-only shells could bypass. mise's own config applies it to every
# invocation at zero shell-startup cost.

# ☁️ AWS
export AWS_CONFIG_FILE="${XDG_CONFIG_HOME}/.aws/config"
export AWS_SHARED_CREDENTIALS_FILE="${XDG_CONFIG_HOME}/.aws/credentials"

# ==============================================================================
# XDG-compliant home migrations
# ==============================================================================
# Node.js / npm
export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME}/npm/npmrc"
export NPM_CONFIG_CACHE="${XDG_CACHE_HOME}/npm"
export NPM_CONFIG_PREFIX="${XDG_DATA_HOME}/npm"

# Yarn (yarn 1 is already XDG-native on Linux: global folder lives in
# ${XDG_DATA_HOME}/yarn; only the cache location is worth pinning)
export YARN_CACHE_FOLDER="${XDG_CACHE_HOME}/yarn"

# Python / IPython
export PYTHONSTARTUP="${XDG_CONFIG_HOME}/python/startup.py"
export IPYTHONDIR="${XDG_CONFIG_HOME}/ipython"

# Keras
export KERAS_HOME="${XDG_CONFIG_HOME}/keras"

# Docker
export DOCKER_CONFIG="${XDG_CONFIG_HOME}/docker"

# GNU Parallel
export PARALLEL_HOME="${XDG_CONFIG_HOME}/parallel"

# Wget
export WGETRC="${XDG_CONFIG_HOME}/wget/wgetrc"

# Mise
export MISE_CONFIG_FILE="${XDG_CONFIG_HOME}/mise/config.toml"
# Git
export GIT_CONFIG_GLOBAL="${XDG_CONFIG_HOME}/git/config"
# Go workspace
export GOPATH="${XDG_DATA_HOME}/go"
export GOBIN="${GOPATH}/bin"

# Atuin
export ATUIN_CONFIG_DIR="${XDG_CONFIG_HOME}/atuin"

# gf patterns
export GF_PATH="${XDG_CONFIG_HOME}/gf"

# Modern CLI tools (zinit-managed). Config dirs are pinned to XDG; macOS would
# otherwise use ~/Library. Cache dirs are left to each tool's own default:
# tealdeer deprecated TEALDEER_CACHE_DIR in 1.8 (it warns on every invocation),
# and on Linux its default already honours XDG_CACHE_HOME, so the pin bought
# nothing. Its replacement — `cache_dir` in config.toml — expands neither ~ nor
# $HOME, so it cannot be tracked portably across /home and /Users.
# The rest of the set (jless, ouch, gping, hexyl, grex, pastel, jnv, rga) either
# has no config file or no env override to pin.
export TEALDEER_CONFIG_DIR="${XDG_CONFIG_HOME}/tealdeer"
export XH_CONFIG_DIR="${XDG_CONFIG_HOME}/xh"

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
  "${NPM_CONFIG_PREFIX}/bin"
  "${XDG_DATA_HOME}/yarn/global/node_modules/.bin"
  "${BUN_INSTALL}/bin"
  "${PNPM_HOME}/bin"
  "${FNM_PATH}"
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
