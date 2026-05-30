#!/usr/bin/env zsh
# ==============================================================================
# .zlogin - Post-Interactive Login Initialization
# ==============================================================================
# This file runs for LOGIN shells AFTER .zshrc completes
#
# LOAD ORDER (Login Shell):
#   1. .zshenv    (environment variables)
#   2. .zprofile  (login-only setup)
#   3. .zshrc     (interactive config)
#   4. .zlogin    ← YOU ARE HERE (post-interactive tasks)
#
# USE THIS FILE FOR:
# - Tasks that must run AFTER the interactive shell is fully configured
# - Displaying information that requires a working prompt
# - Background jobs that should start after shell is ready
#
# RARELY NEEDED - most setup belongs in .zprofile or .zshrc
# ==============================================================================

# Optional: Display system information after prompt is ready
# echo "System uptime: $(uptime)"

# Optional: Check for system updates (non-blocking)
# if (( $+commands[checkupdates] )); then
#     {
#         updates="$(checkupdates 2>/dev/null | wc -l)"
#         [[ "${updates}" -gt 0 ]] && echo "📦 ${updates} package updates available"
#     } &!
# fi
