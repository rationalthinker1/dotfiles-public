# detect_os - Fish-native port of zsh/functions/detect_os.sh
# Sets (and exports) HOST_OS, HOST_LOCATION, IS_DEVCONTAINER so the rest of the
# Fish config can branch on platform exactly like the ZSH side does.
#
#   HOST_OS         - "wsl", "darwin", "linux", "windows", "unknown"
#   HOST_LOCATION   - "desktop" or "server"
#   IS_DEVCONTAINER - "true" or "false"

function detect_os --description 'Detect host OS / location / container'
    # --- Operating system ---
    switch (uname -s)
        case Linux
            if test -f /proc/sys/kernel/osrelease
                and grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
                set -gx HOST_OS wsl
            else
                set -gx HOST_OS linux
            end
        case Darwin
            set -gx HOST_OS darwin
        case 'CYGWIN*' 'MSYS*' 'MINGW*'
            set -gx HOST_OS windows
        case '*'
            set -gx HOST_OS unknown
    end

    # --- Container detection ---
    set -l in_container false
    if test -n "$DEVCONTAINER"; or test -n "$REMOTE_CONTAINERS"
        set in_container true
    else if test -f /.dockerenv
        set in_container true
    else if test -n "$container"; or test -d /var/run/secrets/kubernetes.io
        set in_container true
    else if test -n "$CODESPACES"; or test -n "$GITPOD_WORKSPACE_ID"
        set in_container true
    end
    set -gx IS_DEVCONTAINER $in_container

    # --- Location (desktop vs server) ---
    if test "$IS_DEVCONTAINER" = true
        set -gx HOST_LOCATION server
    else if test "$HOST_OS" = darwin
        set -gx HOST_LOCATION desktop
    else if test -n "$DISPLAY"; or test -n "$WAYLAND_DISPLAY"
        set -gx HOST_LOCATION desktop
    else if command -q dpkg-query
        and dpkg-query -W -f='${Status}' ubuntu-desktop 2>/dev/null | grep -q "install ok installed"
        set -gx HOST_LOCATION desktop
    else
        set -gx HOST_LOCATION server
    end
end
