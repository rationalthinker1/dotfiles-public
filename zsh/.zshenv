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

# 🧭 Base paths (XDG-compliant)
export XDG_CONFIG_HOME="${HOME}/.config"
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export ZSH_CACHE_DIR="${ZDOTDIR}/cache"
