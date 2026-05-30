#!/usr/bin/env zsh
# ==============================================================================
# .zprofile - Login Shell Initialization
# ==============================================================================
# This file runs for LOGIN shells ONLY (after .zshenv, before .zshrc)
#
# LOGIN SHELLS: SSH sessions, terminal startup, macOS login
# NON-LOGIN SHELLS: New terminal tabs/windows (on some systems)
#
# LOAD ORDER (Login Shell):
#   1. .zshenv    (environment variables - ALL shells)
#   2. .zprofile  ← YOU ARE HERE (login-only setup)
#   3. .zshrc     (interactive config - aliases, prompt, plugins)
#   4. .zlogin    (post-.zshrc login tasks - rarely needed)
#
# USE THIS FILE FOR:
# - GUI application environment (macOS launchctl)
# - SSH agent startup
# - Login greeting messages
# - Session initialization that should run ONCE per login
#
# DO NOT PUT HERE:
# - Aliases (→ .zshrc or aliases.zsh)
# - Environment variables (→ .zshenv)
# - Interactive-only config (→ .zshrc)
# ==============================================================================

# macOS: Propagate environment to GUI applications via launchctl
if [[ "${HOST_OS}" == "darwin" ]]; then
    launchctl setenv HOST_OS darwin
    launchctl setenv PATH "${PATH}"
fi

# Optional: Display login message
# echo "Welcome, ${USER}! $(date '+%A, %B %d, %Y %H:%M')"

# Optional: Start SSH agent (if not already running)
# if ! pgrep -u "${USER}" ssh-agent >/dev/null; then
#     eval "$(ssh-agent -s)"
# fi
