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
unset OPENAI_API_KEY 2>/dev/null
unset ANTHROPIC_API_KEY 2>/dev/null
unset GITHUB_TOKEN 2>/dev/null
unset AWS_ACCESS_KEY_ID 2>/dev/null
unset AWS_SECRET_ACCESS_KEY 2>/dev/null

# WSL: Cleanup wslpath cache (keep last 100 entries)
if [[ "${HOST_OS}" == "wsl" ]]; then
    wslpath_cache_file="${ZSH_CACHE_DIR}/wslpath_cache"
    if [[ -f "${wslpath_cache_file}" ]] && (( $(wc -l < "${wslpath_cache_file}") > 100 )); then
        tail -100 "${wslpath_cache_file}" > "${wslpath_cache_file}.tmp"
        mv "${wslpath_cache_file}.tmp" "${wslpath_cache_file}"
    fi
fi

# Optional: Save command statistics
# if (( $+commands[atuin] )); then
#     atuin sync &>/dev/null &
# fi

# Optional: Clear terminal
# clear
