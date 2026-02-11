#!/usr/bin/env bash
# ==============================================================================
# .bashrc - Bash Configuration for Restricted Seedbox Environment
# ==============================================================================
# This configuration is designed for a jailed Docker seedbox with:
#   - HOME="/" (not /home/<user>)
#   - No sudo/root access
#   - No package managers (apt, pip, npm)
#   - Only standard GNU tools available
#
# Uses oh-my-bash framework: https://github.com/ohmybash/oh-my-bash
# ==============================================================================

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Path to oh-my-bash installation
export OSH="/.oh-my-bash"

# oh-my-bash configuration
# OSH_THEME="powerline-plain"  # ASCII-only theme (no Nerd Fonts needed)

# Plugins to load (order matters - only standard tool plugins)
plugins=(
    starship    
    git       # Git aliases and completion
)

# Aliases to enable
aliases=(
    general       # Common aliases (ll, la, etc.)
)

# Completions to enable
completions=(
    git           # Git completion
    ssh           # SSH completion
)

# oh-my-bash settings
DISABLE_AUTO_UPDATE=true               # No auto-update in restricted env
DISABLE_UPDATE_PROMPT=true             # No update prompts
ENABLE_CORRECTION=false                # No command correction
COMPLETION_WAITING_DOTS=true           # Show dots while waiting for completion
HIST_STAMPS="yyyy-mm-dd"               # History timestamp format

# History configuration
HISTSIZE=10000000  # Larger history (10 million commands)
HISTFILESIZE=20000000  # Larger history file
HISTCONTROL=ignoredups:erasedups  # Ignore duplicates
HISTIGNORE="ls:ll:cd:pwd:exit:clear:history:bg:fg"  # Commands to ignore
HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S  "  # Timestamp format
PROMPT_COMMAND="history -a; history -n"  # Append and reload history after each command

# Fix Ctrl+Q/Ctrl+S flow control (allows Ctrl+S for forward search)
# See: https://stackoverflow.com/a/21806557
if [[ -t 0 ]]; then
    stty -ixon
fi

# Load oh-my-bash
if [ -f "$OSH/oh-my-bash.sh" ]; then
    # shellcheck source=/dev/null
    source "$OSH/oh-my-bash.sh"
fi

# Load custom configuration
if [ -f "$OSH/custom/env.sh" ]; then
    # shellcheck source=/dev/null
    . "$OSH/custom/env.sh"
fi

if [ -f "$OSH/custom/aliases.sh" ]; then
    # shellcheck source=/dev/null
    . "$OSH/custom/aliases.sh"
fi

if [ -f "$OSH/custom/functions.sh" ]; then
    # shellcheck source=/dev/null
    . "$OSH/custom/functions.sh"
fi

if [ -f "$OSH/custom/git.sh" ]; then
    # shellcheck source=/dev/null
    . "$OSH/custom/git.sh"
fi

# Machine-specific overrides (optional)
if [ -f "/.bash_local" ]; then
    # shellcheck source=/dev/null
    . "/.bash_local"
fi

# ==============================================================================
# Starship Prompt (if installed)
# ==============================================================================
# Starship is a fast, cross-shell prompt written in Rust
# If available, it will replace the oh-my-bash theme (powerline-plain)
# oh-my-bash is still used for plugins, completions, and aliases
# ==============================================================================
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi
