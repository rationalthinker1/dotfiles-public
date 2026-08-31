#!/usr/bin/env zsh
# ==============================================================================
# dock.zsh - Manual Docker lifecycle for WSL
# ==============================================================================
# Defines `dock` plus its ::usage / ::wait_ready / ::unpin helpers.
#
# Why manual: Docker autostart is deliberately off on this host. The WSL2 VM was
# exhausting RAM+swap, stalling the 9p transport, and getting hard power-cycled by
# WSL (reboot(RB_POWER_OFF)) — an idle Docker stack was a large share of that
# footprint. Both autostart vectors are disabled: the systemd units, and the
# DOCKER_AUTOSTART-gated block in .zshrc. This function is the deliberate way back in.
#
# Containers are all pinned to restart=no so the daemon starting never drags a
# whole stack up with it. `dock unpin` re-applies that after tools (notably the
# Supabase CLI) rewrite the policy back to unless-stopped behind your back.
#
# Subcommands:
#   dock up        Start the daemon (pulls in docker.socket + containerd)
#   dock down      Stop running containers, then the daemon and its socket
#   dock status    Daemon state, running containers, restart-policy drift
#   dock unpin     Reset every container to restart=no
# ==============================================================================

function dock::usage() {
    print -r -- "dock - manual Docker lifecycle (autostart is off by design)

  dock up        Start the daemon (pulls in docker.socket + containerd)
  dock down      Stop running containers, then the daemon and its socket
  dock status    Daemon state, running containers, restart-policy drift
  dock unpin     Reset every container to restart=no

Autostart stays off until you flip it back:
  sudo systemctl enable --now docker
  echo 'export DOCKER_AUTOSTART=1' >> \${ZDOTDIR}/local.zsh"
}

# Poll until the daemon answers, rather than trusting systemd's 'active'.
# systemctl returns as soon as the unit starts; dockerd needs longer to accept API calls.
function dock::wait_ready() {
    local -i timeout="${1:-30}" elapsed=0
    while (( elapsed < timeout )); do
        docker info &>/dev/null && return 0
        sleep 1
        (( elapsed++ ))
    done
    return 1
}

# Containers must not come back on their own — that is what made an idle stack
# a permanent tenant of a VM that could not afford it.
function dock::unpin() {
    local -a all
    all=( ${(f)"$(docker ps -aq 2>/dev/null)"} )
    (( ${#all} )) || return 0
    docker update --restart=no "${all[@]}" &>/dev/null
}

function dock() {
    if ! (( $+commands[docker] )); then
        print -ru2 -- "dock: docker is not installed"
        return 1
    fi

    local action="${1:-status}"

    case "${action}" in
        up)
            if docker info &>/dev/null; then
                print -r -- "✓ Docker already running"
            else
                print -r -- "Starting Docker…"
                sudo systemctl start docker || return 1
                if dock::wait_ready 30; then
                    print -r -- "✓ Docker ready"
                else
                    print -ru2 -- "⚠ Daemon started but did not accept API calls within 30s"
                    return 1
                fi
            fi
            dock::unpin
            dock status
            ;;

        down)
            local -a running
            running=( ${(f)"$(docker ps -q 2>/dev/null)"} )
            if (( ${#running} )); then
                print -r -- "Stopping ${#running} container(s)…"
                docker stop "${running[@]}" &>/dev/null
            fi
            # Stop the socket too: leaving it listening lets the next docker
            # command socket-activate the daemon straight back up.
            sudo systemctl stop docker.service docker.socket containerd.service
            print -r -- "✓ Docker stopped"
            ;;

        unpin)
            dock::unpin
            print -r -- "✓ All containers pinned to restart=no"
            ;;

        status)
            local -a units=( docker.service docker.socket containerd.service )
            local unit
            for unit in "${units[@]}"; do
                printf '  %-20s %s (%s at boot)\n' "${unit}" \
                    "$(systemctl is-active "${unit}" 2>/dev/null)" \
                    "$(systemctl is-enabled "${unit}" 2>/dev/null)"
            done

            if docker info &>/dev/null; then
                local -i count drift
                count=$(docker ps -q 2>/dev/null | wc -l)
                print -r -- "  running containers: ${count}"
                # Anything not 'no' will resurrect itself the next time dockerd starts.
                drift=$(docker ps -aq 2>/dev/null | xargs -r docker inspect \
                    --format '{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null |
                    grep -vc '^no$')
                (( drift )) && \
                    print -r -- "  ⚠ ${drift} container(s) have a restart policy — run 'dock unpin'"
            fi
            ;;

        -h|--help|help)
            dock::usage
            ;;

        *)
            print -ru2 -- "dock: unknown subcommand '${action}'"
            dock::usage
            return 1
            ;;
    esac
}
