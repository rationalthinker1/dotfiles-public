#!/usr/bin/env bash
# ==============================================================================
# env.sh - Environment Variables for Restricted Seedbox
# ==============================================================================
# Loaded by .bashrc via oh-my-bash custom directory
# ==============================================================================

# XDG Base Directory specification (with HOME="/" constraint)
export XDG_CONFIG_HOME="/.config"
export XDG_DATA_HOME="/.local/share"
export XDG_CACHE_HOME="/.cache"

# Claude configuration directory (example for a modern AI CLI tool)
export CLAUDE_CONFIG_DIR="${XDG_CONFIG_HOME}/claude"

# Editor preferences
export EDITOR="vim"
export VISUAL="vim"

# Pager configuration
export PAGER="less"
export LESS="-XRF"  # -X: no init/deinit, -R: ANSI colors, -F: quit if one screen

# Grep colors (green matches)
export GREP_COLOR='1;32'

# LS colors (directories=blue, symlinks=magenta, executables=red)
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34'

# Git configuration
export GIT_PAGER="less -XRF"

# Python configuration (no pip, but python3 available)
export PYTHONDONTWRITEBYTECODE=1  # Don't create __pycache__
export PYTHONUNBUFFERED=1         # Unbuffered output

# Language/locale (use C.UTF-8 as fallback if en_US.UTF-8 not available)
if locale -a 2>/dev/null | grep -q "en_US.utf8\|en_US.UTF-8"; then
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
elif locale -a 2>/dev/null | grep -q "C.UTF-8\|C.utf8"; then
    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
else
    export LANG=C
    export LC_ALL=C
fi

# PATH additions (bash-compatible)
[[ -d "/.local/bin" ]] && export PATH="/.local/bin:${PATH}"
[[ -d "/usr/local/bin" ]] && export PATH="/usr/local/bin:${PATH}"

# Node.js portable installation
[[ -d "/.local/node/bin" ]] && export PATH="/.local/node/bin:${PATH}"

# ==============================================================================
# Modern CLI Tool Configurations
# ==============================================================================

# Bat (cat replacement) - syntax highlighting theme
export BAT_THEME="OneHalfDark"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# Ripgrep configuration file location
export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME}/ripgrep/.ripgreprc"

# FZF (fuzzy finder) configuration
export FZF_DEFAULT_COMMAND="find . -type f 2>/dev/null"  # Basic fallback
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
export FZF_ALT_C_COMMAND="find . -type d 2>/dev/null"
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"
export FZF_CTRL_T_OPTS="--preview 'cat {}'"

# Use better tools if available
if command -v rg >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND="rg --files --smart-case --hidden --follow --glob '!{.git,node_modules,vendor,build}'"
    export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
fi
if command -v fd >/dev/null 2>&1; then
    export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"
fi
if command -v bat >/dev/null 2>&1; then
    export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"
fi

# Git pager (use delta if available, otherwise less)
if command -v delta >/dev/null 2>&1; then
    export GIT_PAGER="delta"
else
    export GIT_PAGER="less -XRF"
fi
