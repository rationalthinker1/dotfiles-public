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
#   HOST_OS           - "wsl", "darwin", "linux", "windows", "unknown"
#   HOST_LOCATION     - "desktop" or "server"
#   IS_DEVCONTAINER   - "true" or "false"
#
# IMPORTANT: Keep this file POSIX sh-compatible!
#   - No bash-isms (no [[ ]], no (( )))
#   - No ZSH-isms (no (( $+commands )))
#   - Use [ ] for tests, not [[ ]]
#   - Use command -v for existence checks
# ==============================================================================

detect_container() {
    # Detect if running in a container
    # Returns 0 (true) if in container, 1 (false) otherwise

    # VS Code Dev Containers
    [ -n "${DEVCONTAINER:-}" ] && return 0
    [ -n "${REMOTE_CONTAINERS:-}" ] && return 0

    # Docker
    [ -f /.dockerenv ] && return 0

    # Systemd containers (podman, systemd-nspawn)
    [ -n "${container:-}" ] && return 0

    # Kubernetes pods (check for kubernetes service account)
    [ -d /var/run/secrets/kubernetes.io ] && return 0

    # GitHub Codespaces
    [ -n "${CODESPACES:-}" ] && return 0

    # Gitpod
    [ -n "${GITPOD_WORKSPACE_ID:-}" ] && return 0

    return 1
}

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

    # Detect if running in container
    if detect_container; then
        IS_DEVCONTAINER="true"
    else
        IS_DEVCONTAINER="false"
    fi

    # Detect location (desktop vs server)
    # Force server mode in containers, even if desktop packages exist
    if [ "${IS_DEVCONTAINER}" = "true" ]; then
        HOST_LOCATION="server"
    elif [ "${HOST_OS}" = "darwin" ]; then
        HOST_LOCATION="desktop"
    elif [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
        HOST_LOCATION="desktop"
    elif command -v dpkg-query >/dev/null 2>&1 && \
         dpkg-query -W -f='${Status}' ubuntu-desktop 2>/dev/null | grep -q "install ok installed"; then
        HOST_LOCATION="desktop"
    else
        HOST_LOCATION="server"
    fi

    # Export for use by calling script
    export HOST_OS HOST_LOCATION IS_DEVCONTAINER
}

# Auto-run if sourced
detect_os
