#!/usr/bin/env sh
# ==============================================================================
# Centralized OS Detection (POSIX-Compatible)
# ==============================================================================
# This file is POSIX sh-compatible and can be sourced by both bash and zsh
#
# Used by:
#   - install.sh (bash bootstrap script)
#   - .zshrc (ZSH interactive configuration)
#
# EXPORTS:
#   HOST_OS       - "wsl", "darwin", "linux", "windows", "unknown"
#   HOST_LOCATION - "desktop" or "server"
#
# IMPORTANT: Keep this file POSIX sh-compatible!
#   - No bash-isms (no [[ ]], no (( )))
#   - No ZSH-isms (no (( $+commands )))
#   - Use [ ] for tests, not [[ ]]
#   - Use command -v for existence checks
# ==============================================================================

detect_os() {
    # Detect operating system
    case "${OSTYPE}" in
        linux-gnu*)
            if [ -f /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
                HOST_OS="wsl"
            else
                HOST_OS="linux"
            fi
            ;;
        darwin*)
            HOST_OS="darwin"
            ;;
        cygwin*|msys*)
            HOST_OS="windows"
            ;;
        *)
            HOST_OS="unknown"
            ;;
    esac

    # Detect location (desktop vs server)
    # Desktop if: macOS, or has DISPLAY, or has ubuntu-desktop package
    if [ "${HOST_OS}" = "darwin" ]; then
        HOST_LOCATION="desktop"
    elif [ -n "${DISPLAY}" ] || [ -n "${WAYLAND_DISPLAY}" ]; then
        HOST_LOCATION="desktop"
    elif command -v dpkg-query >/dev/null 2>&1 && \
         dpkg-query -W -f='${Status}' ubuntu-desktop 2>/dev/null | grep -q "install ok installed"; then
        HOST_LOCATION="desktop"
    else
        HOST_LOCATION="server"
    fi

    # Export for use by calling script
    export HOST_OS HOST_LOCATION
}

# Auto-run if sourced
detect_os
