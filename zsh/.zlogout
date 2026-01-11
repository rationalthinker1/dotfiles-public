#!/usr/bin/env zsh
# ==============================================================================
# .zlogout - Cleanup on Shell Exit
# ==============================================================================
# This file runs when a LOGIN shell exits
#
# USE THIS FILE FOR:
# - Clearing sensitive environment variables
# - Saving session state
# - Cleanup tasks
# - Uploading metrics or logs
#
# DO NOT PUT HERE:
# - Heavy operations that delay shell exit
# - Operations that should run on every shell exit (use trap in .zshrc)
# ==============================================================================

# Clear sensitive variables from environment
unset OPENAI_API_KEY
unset ANTHROPIC_API_KEY
unset GITHUB_TOKEN
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY

# Note: WSL wslpath cache cleanup is handled by trap in .zshrc (runs on all shell exits)

# Optional: Save command statistics
# if (( $+commands[atuin] )); then
#     atuin sync &>/dev/null &
# fi

# Optional: Clear terminal
# clear
