#!/usr/bin/env zsh
# ==============================================================================
# service-audit — audit whatever services this machine actually runs.
#
# WHY THIS EXISTS
#
# One dotfiles tree is deployed to a WSL dev box, a desktop, and several servers that share
# almost no software. hvac-portal runs nginx + mariadb + redis + supervisor; freeswitch runs
# FreeSWITCH + postgres + exim; guhs runs nginx + pm2 + wireguard; the WSL box runs none of
# them. A per-host checklist would rot immediately, and a "server" flag is far too coarse —
# it says nothing about WHICH services are present.
#
# So every check is gated on the thing it inspects actually existing. Run this anywhere: it
# audits what it finds and stays silent about the rest. Adding a service means adding one
# self-guarded function; nothing else changes.
#
# WHAT IT LOOKS FOR, AND WHY THOSE THINGS
#
# Three failure patterns motivated this, none of which a liveness check can see:
#
#   1. ONGOING FAILURE. A unit can be `active` while failing its job every single run — a
#      timer erroring for four months, a vhost serving 500s on every request. `systemctl
#      is-active` passes all of it. What exposes it is an error COUNT that moves: "5xx went
#      0 → 65 since last run" is an alarm, "65 5xx" alone is noise. Hence the state file.
#
#   2. CONFIG THAT NEVER TOOK EFFECT. `slow_query_log = 1` sitting in a MariaDB config that
#      nothing has reloaded since. The file says one thing, the running process another, and
#      reading the file tells you nothing. So the running value is compared against the file.
#
#      Attacked from two directions. The per-service checks compare one KNOWN setting against
#      its running value, which is precise but only ever covers settings someone thought to
#      add. sa::audit_config_drift compares MTIMES instead — if the file is newer than the
#      process, the running process cannot be using it, whatever it says — which is cruder but
#      needs no knowledge of any setting at all and therefore catches the ones nobody
#      anticipated. On the host this was written for it found three in one pass, including an
#      RTP port range whose only symptom would have been intermittent one-way audio.
#
#   3. UNBOUNDED GROWTH. A 10GB application log, an uncapped journal, 2000 rotated files in
#      one directory. Each is invisible until a disk fills.
#
# REPORT, NEVER REPAIR. This command changes nothing — no restarts, no truncation, no
# deletion. It prints the finding and the command that would fix it. A maintenance pass that
# restarts a database because a setting drifted is worse than the drift.
# ==============================================================================

# Where run-over-run counters live. Deltas are the entire point of several checks, and they
# need somewhere to persist that is not the log directory.
typeset -g SERVICE_AUDIT_STATE="${XDG_STATE_HOME:-${HOME}/.local/state}/service-audit/state"

# A log file at or above this size is reported regardless of rotation config.
typeset -g SERVICE_AUDIT_LOG_MAX_BYTES=$(( 500 * 1024 * 1024 ))

# Restart count above which a unit is treated as flapping rather than merely running.
typeset -g SERVICE_AUDIT_RESTART_WARN=5

# A telephony channel older than this is a channel that never tore down, not a long call.
# Six hours is far beyond any real call and far below the days-long ones this catches.
typeset -g SERVICE_AUDIT_FS_CHANNEL_MAX_HOURS=6

# A single call recording larger than this did not stop when the call did. At the 96 kbps
# these are encoded at, 100 MB is roughly 2.4 hours of audio.
typeset -g SERVICE_AUDIT_FS_RECORDING_MAX_MB=100

# ---------------------------------------------------------------------------------------
# Output helpers. Deliberately the same markers maintain uses (✓ ⚠️ ℹ️ ──) so that when this
# runs inside a maintain pass, maintain::colorize paints it with no special-casing.
# ---------------------------------------------------------------------------------------

# `quiet` is read from service_audit's locals through dynamic scoping. Findings are always
# RECORDED; only the printing is suppressed, so --quiet still returns the right verdict and
# still writes the state file.
function sa::hdr()  { (( quiet )) || { print -r -- ""; print -r -- "  ── ${1} ────────────────────────────────" } }
function sa::ok()   { (( quiet )) || print -r -- "    ✓ ${1}" }
function sa::info() { (( quiet )) || print -r -- "    ℹ️ ${1}" }
function sa::warn() { sa_findings+=( "${1}" ); (( quiet )) || print -r -- "    ⚠️ ${1}" }
function sa::fix()  { (( quiet )) || print -r -- "       → ${1}" }
# An indented detail line beneath a finding. Exists so these go through the quiet gate too
# — bare `print` calls in the detail loops were the reason --quiet still printed a wall of
# file paths while claiming to emit only the verdict.
function sa::item() { (( quiet )) || print -r -- "        ${1}" }
# A check that could not run for lack of privilege. Counted and named once at the end
# rather than printed as a warning: a skipped check is not a finding, but a run that
# silently covered less than you think is worse than one that says so.
function sa::skip() { sa_skipped+=( "${1}" ); (( quiet )) || print -r -- "    (${1} — needs root, skipped)" }

# Run a command with privilege if required and available.
#
# `sudo -n` first: inside a maintain pass the credential is already primed, so this never
# prompts. Standalone it may prompt once, which is deliberate — a human running
# `service-audit` by hand would rather type a password than get a half-audit.
#
# --no-prompt suppresses ONLY the interactive branch; the `sudo -n` path above it still
# runs. That distinction is what makes the flag safe for maintain to pass: phase 7 invokes
# this inside `$(… 2>/dev/null)`, so a password prompt there would have its text discarded
# and the whole weekly run would sit waiting on a tty for input nobody knows it wants.
function sa::sudo() {
    if (( EUID == 0 )); then
        "$@"
    elif (( ${+commands[sudo]} )); then
        if (( sa_sudo_ok )); then
            sudo "$@"
        elif sudo -n true 2>/dev/null; then
            sa_sudo_ok=1; sudo "$@"
        elif (( sa_sudo_prompt )) && [[ -t 0 ]]; then
            # Ask at most once per run, not per check.
            sa_sudo_prompt=0
            if sudo -v 2>/dev/null; then sa_sudo_ok=1; sudo "$@"; else return 127; fi
        else
            return 127
        fi
    else
        return 127
    fi
}

# Resolve a tool that may live in an sbin directory, printing its absolute path.
#
# ufw, iptables and their neighbours live in /usr/sbin, which is on root's PATH and NOT on an
# ordinary user's. So `(( ${+commands[ufw]} ))` answers "not installed" for every non-root
# run, and a check gated on it returns early and reports nothing — indistinguishable, in the
# output, from a clean result. That is the worst possible failure for an audit: it looks like
# coverage. Returns non-zero only when the tool is genuinely absent.
function sa::bin() {
    local name="${1}" candidate
    (( ${+commands[${name}]} )) && { print -r -- "${commands[${name}]}"; return 0 }
    for candidate in /usr/sbin/"${name}" /sbin/"${name}" /usr/local/sbin/"${name}"; do
        [[ -x "${candidate}" ]] && { print -r -- "${candidate}"; return 0 }
    done
    return 1
}

# Where does THIS host keep its FreeSWITCH config? Derived from the running process, never
# assumed, because sa::fs_cli below needs it before fs_cli can be asked anything.
#
# Order, most authoritative first:
#   1. an explicit `-conf <dir>` on the running command line, which overrides everything
#   2. <prefix>/conf, where prefix comes from resolving /proc/<pid>/exe and stripping
#      /bin/freeswitch — this is how a source build is laid out
#   3. /etc/freeswitch, the Debian/Ubuntu package default
#
# Not resolved through readlink here: callers that want the real directory behind a symlink
# resolve it themselves, and the vars.xml read below works either way.
function sa::fs_conf_dir() {
    local pid conf exe prefix
    pid="$(systemctl show freeswitch -p MainPID --value 2>/dev/null)"
    if [[ "${pid}" == <1-> ]]; then
        local -a argv_fs=( ${(0)"$(sudo -n cat /proc/${pid}/cmdline 2>/dev/null || cat /proc/${pid}/cmdline 2>/dev/null)"} )
        local i
        for (( i = 1; i <= ${#argv_fs}; i++ )); do
            [[ "${argv_fs[i]}" == "-conf" ]] && { conf="${argv_fs[i+1]}"; break }
        done
        [[ -d "${conf}" ]] && { print -r -- "${conf}"; return 0 }
        exe="$(sudo -n readlink -f /proc/${pid}/exe 2>/dev/null || readlink -f /proc/${pid}/exe 2>/dev/null)"
        prefix="${exe%/bin/freeswitch}"
        [[ -n "${prefix}" && "${prefix}" != "${exe}" && -d "${prefix}/conf" ]] && { print -r -- "${prefix}/conf"; return 0 }
    fi
    [[ -d /etc/freeswitch ]] && { print -r -- /etc/freeswitch; return 0 }
    return 1
}

# fs_cli that works when the audit runs as root.
#
# This is not a style preference, it is a correctness fix. `fs_cli -x` takes its credentials
# from ~/.fs_cli_conf. An interactive user usually has one; ROOT USUALLY DOES NOT, and the
# weekly audit runs from a systemd timer as root. Every bare `fs_cli -x` in this file returned
# nothing on that run, so the entire FreeSWITCH section - uptime, channel count, stuck-channel
# detection, sofia profiles, gateway registration, oversized recordings, RTP port range, seven
# checks - was missing from every emailed report, and sa::fs_dir silently fell back to the
# /etc/freeswitch guess on hosts where that is the wrong answer.
#
# Bare is still tried FIRST: it is cheaper, and it respects a user who has deliberately
# configured their own ~/.fs_cli_conf pointing somewhere non-default. Only on empty output do
# we go looking for the password.
#
# The password is read from vars.xml in the directory sa::fs_conf_dir found. That file is
# typically 0640 root:freeswitch, so this path needs root or group membership - which is
# exactly the case we are fixing.
function sa::fs_cli() {
    (( ${+commands[fs_cli]} )) || return 1
    local out
    out="$(fs_cli -x "${1}" -t 2000 2>/dev/null)"
    [[ -n "${out}" ]] && { print -r -- "${out}"; return 0 }

    if (( ! ${+_sa_fs_esl_args} )); then
        typeset -ga _sa_fs_esl_args=()
        local conf pw host port
        conf="$(sa::fs_conf_dir)" || conf=""
        if [[ -n "${conf}" && -r "${conf}/vars.xml" ]]; then
            pw="$(grep -oP 'event_socket_password=\K[^"]+' "${conf}/vars.xml" 2>/dev/null | head -1)"
            # listen-ip/listen-port may be literals or $${var} references back into vars.xml;
            # only a literal is usable, and the defaults are right in every other case.
            host="$(grep -oP 'name="listen-ip"\s+value="\K[^"$]+' "${conf}/autoload_configs/event_socket.conf.xml" 2>/dev/null | head -1)"
            port="$(grep -oP 'name="listen-port"\s+value="\K[0-9]+' "${conf}/autoload_configs/event_socket.conf.xml" 2>/dev/null | head -1)"
            [[ -n "${pw}" ]] && _sa_fs_esl_args=( -H "${host:-127.0.0.1}" -P "${port:-8021}" -p "${pw}" )
        fi
    fi

    (( ${#_sa_fs_esl_args} )) || return 1
    fs_cli "${_sa_fs_esl_args[@]}" -x "${1}" -t 2000 2>/dev/null
}

# Ask the RUNNING FreeSWITCH where one of its directories is, rather than assuming a layout.
#
# Installs disagree completely: a Debian package uses /etc/freeswitch with recordings under
# /var/lib/freeswitch, a source build uses /usr/local/freeswitch/{conf,log,recordings}, some
# deployments use /opt/freeswitch, and `freeswitch -conf <dir>` overrides any of them.
# global_getvar reports what THIS process actually uses, which is the only answer that cannot
# be out of date.
#
# Resolved with readlink -f because conf_dir is very often a symlink — on the host this was
# written for, /usr/local/freeswitch/conf -> /etc/freeswitch. Comparing mtimes through the
# unresolved path would stat the symlink instead of the files behind it.
function sa::fs_dir() {
    local name="${1}" val
    val="$(sa::fs_cli "global_getvar ${name}" | head -1)"
    [[ -n "${val}" && "${val}" != -ERR* ]] || return 1
    readlink -f "${val}" 2>/dev/null || print -r -- "${val}"
}

# Every directory recordings might actually land in, one per line.
#
# ${recordings_dir} alone is NOT sufficient and trusting it is a real trap. A dialplan may
# write anywhere it likes, and on the host this was written for it did: recordings_dir was an
# empty /usr/local/freeswitch/recordings while every recording went to /var/recordings.
# Checking only the global would have missed a 31.6 GiB runaway file sitting in the other one.
#
# So: the global, plus any directory the dialplan names in a record_session or recording_file
# argument. Discovered from config rather than listed here, so this works on a host whose
# dialplan records somewhere neither of us has thought of.
function sa::fs_recording_dirs() {
    local conf_dir="${1}"
    local -aU dirs=()
    local rec; rec="$(sa::fs_dir recordings_dir)" && [[ -d "${rec}" ]] && dirs+=( "${rec}" )

    if [[ -d "${conf_dir}" ]]; then
        local -a found d
        found=( ${(f)"$(grep -rhoP '(?:record_session|recording_file)[^/]*\K/[A-Za-z0-9_./-]+' \
            "${conf_dir}" 2>/dev/null | sed 's#/[^/]*$##' | sort -u)"} )
        for d in ${found}; do
            [[ -n "${d}" && -d "${d}" ]] && dirs+=( "${d:A}" )
        done
    fi
    print -rl -- ${dirs}
}

# Is a systemd unit present and running? Used as the gate for service checks whose binary
# may exist as a client-only package (redis-cli without redis-server, mysql without mariadb).
function sa::unit_active() {
    (( ${+commands[systemctl]} )) || return 1
    systemctl is-active --quiet "${1}" 2>/dev/null
}

# ---------------------------------------------------------------------------------------
# Run-over-run counters.
# ---------------------------------------------------------------------------------------

function sa::metric() { sa_metrics[${1}]="${2//[$'\n\r']/ }" }

function sa::human() {
    local -i b=${1:-0}
    if   (( b >= 1073741824 )); then printf '%.1fG' $(( b / 1073741824.0 ))
    elif (( b >= 1048576 ));    then printf '%.0fM' $(( b / 1048576.0 ))
    elif (( b >= 1024 ));       then printf '%.0fK' $(( b / 1024.0 ))
    else                             printf '%dB' ${b}
    fi
}

# Compare this run's counters with the previous run's and report only what moved.
#
# A key absent from the previous file is a FIRST READING, not a change. Reporting "0 → 65"
# for something never measured before would fire on every fresh machine and teach you to
# ignore the section, which is the one outcome that makes this worthless.
function sa::report_deltas() {
    local -A prev=()
    local line key cur old
    if [[ -r "${SERVICE_AUDIT_STATE}" ]]; then
        while IFS= read -r line; do
            [[ "${line}" == *=* ]] || continue
            prev[${line%%=*}]="${line#*=}"
        done < "${SERVICE_AUDIT_STATE}"
    fi

    local -a moved=() fresh=()
    for key in ${(ok)sa_metrics}; do
        cur="${sa_metrics[${key}]}"
        if (( ! ${+prev[${key}]} )); then fresh+=( "${key}" ); continue; fi
        [[ "${prev[${key}]}" == "${cur}" ]] || moved+=( "${key}" )
    done

    if (( ${#moved} )); then
        local age="unknown"
        if [[ -r "${SERVICE_AUDIT_STATE}" ]]; then
            zmodload -F zsh/stat b:zstat 2>/dev/null
            local -i mt=$(zstat +mtime "${SERVICE_AUDIT_STATE}" 2>/dev/null || print 0)
            (( mt > 0 )) && age="$(( (EPOCHSECONDS - mt) / 86400 ))d $(( ((EPOCHSECONDS - mt) % 86400) / 3600 ))h ago"
        fi
        sa::hdr "Since last run (${age})"
        for key in "${(o)moved[@]}"; do
            old="${prev[${key}]}"; cur="${sa_metrics[${key}]}"
            [[ "${key}" == *_bytes ]] && { old="$(sa::human ${old})"; cur="$(sa::human ${cur})" }
            # Direction decides severity. More errors is bad; fewer is the fix landing.
            if [[ "${key}" == (*error*|*fail*|*5xx*|*queue*|*restart*) ]] \
               && (( ${sa_metrics[${key}]} > ${prev[${key}]} )); then
                sa::warn "${key}: ${old} → ${cur}"
            else
                sa::ok "${key}: ${old} → ${cur}"
            fi
        done
    fi
    (( ${#fresh} )) && print -r -- "    · ${#fresh} counter(s) recorded for the first time"

    # Persist even when nothing moved — the mtime is what dates the next run's header.
    mkdir -p "${SERVICE_AUDIT_STATE:h}" 2>/dev/null || return 0
    local tmp="${SERVICE_AUDIT_STATE}.new"
    : > "${tmp}" 2>/dev/null || return 0
    for key in ${(ok)sa_metrics}; do print -r -- "${key}=${sa_metrics[${key}]}" >> "${tmp}"; done
    mv -f "${tmp}" "${SERVICE_AUDIT_STATE}" 2>/dev/null
}

# ---------------------------------------------------------------------------------------
# Per-service audits. Each is self-guarded and returns immediately when its service is absent.
# ---------------------------------------------------------------------------------------

function sa::audit_systemd() {
    (( ${+commands[systemctl]} )) || return 0
    [[ -d /run/systemd/system ]] || return 0
    sa::hdr "systemd units"

    local failed
    failed="$(systemctl list-units --failed --no-legend --plain 2>/dev/null | awk '{print $1}')"
    local -a failed_units=( ${(f)failed} )
    failed_units=( ${failed_units:#} )
    sa::metric "systemd_failed" ${#failed_units}
    if (( ${#failed_units} )); then
        sa::warn "${#failed_units} failed unit(s): ${(j:, :)failed_units}"
        sa::fix "systemctl status <unit>  /  journalctl -u <unit> -p err"
    else
        sa::ok "no failed units"
    fi

    # The "active but failing" case: a unit that keeps dying and being restarted reports
    # active the whole time. NRestarts is the only field that exposes it.
    local -a flapping=()
    local unit n
    for unit in ${(f)"$(systemctl list-units --type=service --state=running --no-legend --plain 2>/dev/null | awk '{print $1}')"}; do
        [[ -n "${unit}" ]] || continue
        n="$(systemctl show "${unit}" -p NRestarts --value 2>/dev/null)"
        [[ "${n}" == <-> ]] || continue
        (( n >= SERVICE_AUDIT_RESTART_WARN )) && flapping+=( "${unit%.service}=${n}" )
    done
    if (( ${#flapping} )); then
        sa::warn "${#flapping} unit(s) restarting repeatedly: ${(j:, :)flapping}"
        sa::fix "journalctl -u <unit> --since '1 week ago' -p err"
    fi

    # Journal error volume as a delta. An absolute count means nothing; a jump means a lot.
    if (( ${+commands[journalctl]} )); then
        local errs
        errs="$(sa::sudo journalctl -b -p err --no-pager -q 2>/dev/null | wc -l)"
        if [[ "${errs// /}" == <-> ]]; then
            sa::metric "journal_errors_this_boot" "${errs// /}"
            sa::info "journal errors this boot: ${errs// /}"
        else
            sa::skip "journal error count"
        fi
        local jsize
        jsize="$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMG]' | tail -1)"
        [[ -n "${jsize}" ]] && sa::info "journal on disk: ${jsize}"
    fi
}

function sa::audit_nginx() {
    (( ${+commands[nginx]} )) || return 0
    sa::hdr "nginx"

    # Config validity first: everything below is meaningless if the running config is stale
    # or broken, and `nginx -t` is the only check that reads what a reload would actually load.
    # rc 127 is sa::sudo's "could not escalate", NOT nginx's verdict. Unprivileged, nginx -t
    # fails opening the pid/log paths and would otherwise be reported as a config error on
    # every non-root run — a false alarm on a check people would act on.
    sa::sudo nginx -t &>/dev/null
    local ngx_rc=$?
    if   (( ngx_rc == 0 ));   then sa::ok "configuration valid"
    elif (( ngx_rc == 127 )); then sa::skip "nginx configuration test"
    else
        sa::warn "nginx -t reports a configuration error"
        sa::fix "sudo nginx -t"
    fi

    local -a vhosts=( /etc/nginx/sites-enabled/*(N) )
    (( ${#vhosts} )) && sa::info "${#vhosts} vhost(s) enabled"

    # 5xx counts from LIVE access logs only — never .1 or .gz. On a busy host the rotated
    # set runs to thousands of files, and the delta against last run is what carries the
    # signal anyway. The pattern matches the status field of the combined-ish formats
    # ("...HTTP/1.1" 500 1234), which is format-agnostic enough for custom log_formats.
    local -a live_logs=( /var/log/nginx/*.log(N.) )
    if (( ${#live_logs} )); then
        local lg name n total=0
        for lg in "${live_logs[@]}"; do
            [[ "${lg}" == *access* || "${lg}" == */access.log ]] || continue
            n="$(grep -cE '" 5[0-9]{2} ' "${lg}" 2>/dev/null)" || n=0
            name="${${lg:t}%.log}"
            sa::metric "nginx_5xx_${name}" "${n:-0}"
            (( total += n ))
        done
        sa::metric "nginx_5xx_total" "${total}"
        (( total > 0 )) && sa::info "${total} 5xx across ${#live_logs} live log(s) — see the delta section"
        (( total == 0 )) && sa::ok "no 5xx in live access logs"
    fi

    # Rotated-file sprawl. 2000 files in one directory is its own growth problem and no
    # size threshold catches it, because each file is small.
    local -a all_logs=( /var/log/nginx/*(N.) )
    (( ${#all_logs} > 500 )) && {
        sa::warn "${#all_logs} files in /var/log/nginx — rotation is keeping too many"
        sa::fix "tune rotate/maxage in /etc/logrotate.d/nginx"
    }
}

# MariaDB / MySQL. The point is pattern 2: a setting edited in the config file but never
# loaded, because nothing restarted the server since. Comparing the running value with the
# file is the only way to see it — reading either alone looks correct.
function sa::audit_mysql() {
    (( ${+commands[mysql]} )) || return 0
    sa::unit_active mariadb || sa::unit_active mysql || sa::unit_active mysqld || return 0
    sa::hdr "MariaDB / MySQL"

    local running
    running="$(sa::sudo mysql -N -B -e 'SELECT 1' 2>/dev/null)"
    if [[ "${running}" != 1 ]]; then
        sa::skip "MariaDB running-configuration comparison"
        return 0
    fi

    local uptime conns
    uptime="$(sa::sudo mysql -N -B -e "SHOW GLOBAL STATUS LIKE 'Uptime'" 2>/dev/null | awk '{print $2}')"
    conns="$(sa::sudo mysql -N -B -e "SHOW GLOBAL STATUS LIKE 'Threads_connected'" 2>/dev/null | awk '{print $2}')"
    [[ "${uptime}" == <-> ]] && sa::info "up $(( uptime / 86400 ))d, ${conns:-?} connection(s)"
    [[ "${conns}" == <-> ]] && sa::metric "mysql_connections" "${conns}"

    # Settings worth comparing: each is one somebody edits and then forgets to reload.
    #
    # NAMING: not `watch`, `path`, `status`, `fpath`, `argv` or any other zsh special. zsh
    # ties these to real shell behaviour and `local` does NOT break the tie — `status` is
    # read-only and aborts the function, `path` silently wipes $PATH, and `watch` quietly
    # enrols zsh in login-monitoring for whatever strings you stored. All three were hit
    # while writing this file.
    local -a watched=( slow_query_log long_query_time max_connections innodb_buffer_pool_size )
    local var file_val run_val f
    local -a cfgs=( /etc/mysql/**/*.cnf(N) /etc/my.cnf(N) /etc/my.cnf.d/**/*.cnf(N) )
    for var in "${watched[@]}"; do
        run_val="$(sa::sudo mysql -N -B -e "SHOW GLOBAL VARIABLES LIKE '${var}'" 2>/dev/null | awk '{print $2}')"
        [[ -n "${run_val}" ]] || continue
        file_val=""
        for f in "${cfgs[@]}"; do
            file_val="$(grep -hoP "^\s*${var}\s*=\s*\K\S+" "${f}" 2>/dev/null | tail -1)"
            [[ -n "${file_val}" ]] && break
        done
        [[ -n "${file_val}" ]] || continue
        # Normalise the booleans MySQL renders as ON/OFF but people write as 1/0.
        local norm_run="${run_val:l}" norm_file="${file_val:l}"
        [[ "${norm_run}" == on  ]] && norm_run=1
        [[ "${norm_run}" == off ]] && norm_run=0
        [[ "${norm_file}" == on  ]] && norm_file=1
        [[ "${norm_file}" == off ]] && norm_file=0
        if [[ "${norm_run}" != "${norm_file}" ]]; then
            sa::warn "${var}: file=${file_val} running=${run_val} — config edited but never reloaded"
            sa::fix "sudo systemctl reload mariadb   (verify the change is safe first)"
        fi
    done
}

function sa::audit_postgres() {
    (( ${+commands[psql]} )) || return 0
    systemctl list-units --type=service --state=running --no-legend --plain 2>/dev/null \
        | grep -q postgresql || return 0
    sa::hdr "PostgreSQL"

    # Run as the postgres role, which needs a different mechanism depending on who we are:
    # as root, sudo is not involved at all and `sa::sudo -u postgres …` would try to execute
    # a command literally named "-u".
    local -a as_pg=()
    if   (( EUID == 0 ));            then as_pg=( runuser -u postgres -- )
    elif (( ${+commands[sudo]} ));   then as_pg=( sudo -u postgres )
    else return 0
    fi
    local out
    out="$("${as_pg[@]}" psql -tAc 'SELECT count(*) FROM pg_stat_activity' 2>/dev/null)"
    if [[ "${out}" == <-> ]]; then
        sa::info "${out} active connection(s)"
        sa::metric "postgres_connections" "${out}"
        local longq
        longq="$("${as_pg[@]}" psql -tAc "SELECT count(*) FROM pg_stat_activity WHERE state='active' AND now()-query_start > interval '5 minutes'" 2>/dev/null)"
        [[ "${longq}" == <-> && ${longq} -gt 0 ]] && sa::warn "${longq} query/queries running over 5 minutes"
    else
        sa::skip "PostgreSQL connection statistics"
    fi
}

function sa::audit_redis() {
    (( ${+commands[redis-cli]} )) || return 0
    sa::unit_active redis-server || sa::unit_active redis || return 0
    sa::hdr "Redis"

    local pong; pong="$(redis-cli ping 2>/dev/null)"
    if [[ "${pong}" != PONG ]]; then
        sa::warn "redis-cli ping did not return PONG"
        return 0
    fi

    local used maxmem policy lastsave
    used="$(redis-cli info memory 2>/dev/null | grep -oP '^used_memory:\K[0-9]+' )"
    maxmem="$(redis-cli config get maxmemory 2>/dev/null | tail -1)"
    policy="$(redis-cli config get maxmemory-policy 2>/dev/null | tail -1)"
    [[ "${used}" == <-> ]] && { sa::info "memory in use: $(sa::human ${used})"; sa::metric "redis_memory_bytes" "${used}" }

    # An unbounded Redis with no eviction policy will take the box down rather than shed
    # data. Worth stating because both defaults look harmless in isolation.
    if [[ "${maxmem}" == 0 && "${policy}" == noeviction ]]; then
        sa::warn "maxmemory unlimited with noeviction — Redis will grow until the OOM killer acts"
        sa::fix "redis-cli config set maxmemory <bytes>  (and persist it in redis.conf)"
    fi

    # The classic: fork-based BGSAVE needs overcommit, and Redis warns about this at boot
    # where nobody reads it.
    local oc; oc="$(sysctl -n vm.overcommit_memory 2>/dev/null)"
    [[ "${oc}" == 0 ]] && {
        sa::warn "vm.overcommit_memory=0 — background saves may fail under memory pressure"
        sa::fix "echo 'vm.overcommit_memory = 1' | sudo tee /etc/sysctl.d/60-redis.conf && sudo sysctl -p"
    }

    lastsave="$(redis-cli info persistence 2>/dev/null | grep -oP '^rdb_last_bgsave_status:\K\S+')"
    [[ -n "${lastsave}" && "${lastsave}" != ok ]] && sa::warn "last background save status: ${lastsave}"
}

function sa::audit_phpfpm() {
    local -a pools=( /etc/php/*/fpm(N/) )
    (( ${#pools} )) || return 0
    sa::hdr "PHP-FPM"

    local -a running=( ${(f)"$(systemctl list-units --type=service --state=running --no-legend --plain 2>/dev/null | awk '{print $1}' | grep '^php.*fpm' )"} )
    running=( ${running:#} )
    if (( ${#running} == 0 )); then
        sa::info "no php-fpm service running"
        return 0
    fi
    sa::ok "${#running} pool service(s) running: ${(j:, :)${(@)running%.service}}"

    # More than one PHP version serving traffic is usually a half-finished upgrade: the
    # vhosts point at one socket, the packages keep both patched, and nobody notices.
    (( ${#running} > 1 )) && {
        sa::warn "multiple PHP versions active — vhosts may be split across them"
        sa::fix "grep -rh fastcgi_pass /etc/nginx/sites-enabled/ | sort -u"
    }

    local cli_v
    cli_v="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)"
    [[ -n "${cli_v}" ]] && sa::info "php CLI is ${cli_v}"
}

function sa::audit_supervisor() {
    (( ${+commands[supervisorctl]} )) || return 0
    sa::unit_active supervisor || sa::unit_active supervisord || return 0
    sa::hdr "Supervisor"

    local out; out="$(sa::sudo supervisorctl status 2>/dev/null)"
    if [[ -z "${out}" ]]; then sa::skip "supervisor program status"; return 0; fi

    local -a bad=( ${(f)"$(print -r -- "${out}" | grep -vE '\bRUNNING\b')"} )
    bad=( ${bad:#} )
    local -i total=$(print -r -- "${out}" | grep -c .)
    if (( ${#bad} )); then
        sa::warn "${#bad} of ${total} program(s) not RUNNING"
        local b; for b in "${bad[@]}"; do sa::item "${b}"; done
        sa::fix "sudo supervisorctl restart <name>"
    else
        sa::ok "all ${total} program(s) RUNNING"
    fi
    sa::metric "supervisor_not_running" "${#bad}"
}

function sa::audit_freeswitch() {
    (( ${+commands[fs_cli]} )) || return 0
    sa::hdr "FreeSWITCH"

    if ! sa::unit_active freeswitch; then
        sa::warn "fs_cli present but the freeswitch service is not running"
        return 0
    fi

    # -t 2000: fs_cli blocks on a wedged event socket, which is exactly the state worth
    # reporting rather than hanging the audit on.
    # fs_status, not `status`: zsh's $status is a READ-ONLY alias for $?, so `local status`
    # aborts the function outright with "read-only variable". Third reserved name to bite
    # this file after `path` and `watch` — see the note above sa::audit_mysql.
    local fs_status; fs_status="$(sa::fs_cli 'status')"
    if [[ -z "${fs_status}" ]]; then
        sa::warn "freeswitch is running but its event socket did not answer"
        sa::fix "check ESL config in autoload_configs/event_socket.conf.xml"
        return 0
    fi

    # "UP 0 years, 35 days, 11 hours, 53 minutes, ..." — drop the leading zero-valued units
    # so this reads "35 days, 11 hours" rather than the useless "0 years".
    local up_raw; up_raw="$(print -r -- "${fs_status}" | grep -oP '^UP \K.*' | head -1)"
    if [[ -n "${up_raw}" ]]; then
        local -a parts=( ${(s:, :)up_raw} )
        while (( ${#parts} > 1 )) && [[ "${parts[1]}" == 0\ * ]]; do shift parts; done
        sa::ok "up ${(j:, :)parts[1,2]}"
    fi

    local cur; cur="$(sa::fs_cli 'show channels count' | grep -oE '^[0-9]+')"
    [[ "${cur}" == <-> ]] && { sa::info "${cur} active channel(s)"; sa::metric "freeswitch_channels" "${cur}" }

    # A sofia profile that is not RUNNING means that SIP leg is dead — registrations fail
    # and calls do not arrive, while the service itself stays happily active.
    # `sofia status` is TAB-separated: Name, Type, Data, State. Keying on the Type column is
    # what makes this reliable — a naive /profile/ match also catches the trailing summary
    # line ("1 profile 0 aliases") and reports a profile literally named "1".
    local sofia; sofia="$(sa::fs_cli 'sofia status')"
    if [[ -n "${sofia}" ]]; then
        local -a prof_down=( ${(f)"$(print -r -- "${sofia}" | awk -F'\t+' '$2=="profile" && $4 !~ /^RUNNING/ {gsub(/^ +| +$/,"",$1); print $1}')"} )
        prof_down=( ${prof_down:#} )
        (( ${#prof_down} )) && { sa::warn "sofia profile(s) not RUNNING: ${(j:, :)prof_down}"; sa::fix "fs_cli -x 'sofia profile <name> restart'" } \
                            || sa::ok "all sofia profiles RUNNING"

        # Gateways are the outbound trunks. FAIL_WAIT/FAILED means registration is actively
        # failing and calls through that carrier are not completing — while FreeSWITCH
        # itself stays perfectly healthy. NOREG is excluded: it is the normal state for a
        # gateway configured without registration.
        local -a gw_bad=( ${(f)"$(print -r -- "${sofia}" | awk -F'\t+' '$2=="gateway" && $4 ~ /FAIL/ {gsub(/^ +| +$/,"",$1); print $1" ("$4")"}')"} )
        gw_bad=( ${gw_bad:#} )
        sa::metric "freeswitch_gateways_failing" ${#gw_bad}
        (( ${#gw_bad} )) && { sa::warn "SIP gateway(s) failing to register: ${(j:, :)gw_bad}"; sa::fix "fs_cli -x 'sofia profile external killgw <name>' then check credentials" }
    fi

    # STUCK CHANNELS. A channel up for hours is not a long call, it is a channel that never
    # tore down: the far end vanished without a BYE and nothing timed it out. Channel COUNT
    # cannot see this — four channels looks like a busy switch, not a fault.
    #
    # This is the cheapest detector for an entire failure class. On 2026-09-13 the freeswitch
    # host had four such channels aged 16.6 and 6.3 DAYS, and an earlier one had held
    # record_session open for 32.8 days and written a 31.6 GiB mp3 — 43% of the root
    # filesystem — before anyone noticed.
    #
    # `show channels` is CSV; created_epoch is column 4 and the state name is column 6.
    local chans; chans="$(sa::fs_cli 'show channels')"
    if [[ -n "${chans}" ]]; then
        local -a stuck
        stuck=( ${(f)"$(print -r -- "${chans}" | awk -F, -v now="$(date +%s)" -v maxh="${SERVICE_AUDIT_FS_CHANNEL_MAX_HOURS}" '
            NR > 1 && $4 ~ /^[0-9]+$/ {
                age = (now - $4) / 3600
                if (age > maxh) printf "%s (%.1fh, %s)\n", substr($1, 1, 14), age, $6
            }')"} )
        stuck=( ${stuck:#} )
        sa::metric "freeswitch_stuck_channels" ${#stuck}
        if (( ${#stuck} )); then
            sa::warn "${#stuck} channel(s) older than ${SERVICE_AUDIT_FS_CHANNEL_MAX_HOURS}h — almost certainly never torn down"
            local ch; for ch in ${stuck[1,5]}; do sa::item "${ch}"; done
            sa::fix "fs_cli -x 'uuid_kill <uuid>'; then set rtp-timeout-sec in the sofia profile so it cannot recur"
        else
            sa::ok "no channels older than ${SERVICE_AUDIT_FS_CHANNEL_MAX_HOURS}h"
        fi
    fi

    # RUNAWAY RECORDINGS. The direct consequence of the above when record_session is running.
    # Checked independently because the recording outlives the channel that made it: the
    # channel is long gone, the file is still on disk, and nothing else will ever mention it.
    local fs_conf; fs_conf="$(sa::fs_dir conf_dir)"
    local rec_dir
    for rec_dir in ${(f)"$(sa::fs_recording_dirs "${fs_conf}")"}; do
        [[ -n "${rec_dir}" && -d "${rec_dir}" ]] || continue
        local -a huge
        huge=( ${(f)"$(find "${rec_dir}" -maxdepth 2 -type f -size +${SERVICE_AUDIT_FS_RECORDING_MAX_MB}M -printf '%s %p\n' 2>/dev/null | sort -rn | head -5)"} )
        huge=( ${huge:#} )
        sa::metric "freeswitch_oversized_recordings" ${#huge}
        if (( ${#huge} )); then
            sa::warn "${#huge} recording(s) over ${SERVICE_AUDIT_FS_RECORDING_MAX_MB}MB in ${rec_dir}"
            local h; for h in ${huge}; do sa::item "$(sa::human ${h%% *}) — ${h#* }"; done
            sa::fix "a call recording this large means the channel never hung up — check 'show channels' ages too"
        else
            sa::ok "no oversized recordings in ${rec_dir}"
        fi
    done

    # RTP RANGE vs FIREWALL. A mismatch here does not raise an error anywhere: RTP simply
    # gets allocated on a port the firewall drops, and the symptom is intermittent ONE-WAY
    # AUDIO on a switch that reports itself perfectly healthy. Worth comparing because the
    # config file and the running process can disagree — on 2026-09-13 this host had the
    # range corrected in switch.conf.xml six days AFTER FreeSWITCH last started, so the
    # running process still used the old one while the file looked right.
    local sw_conf="${fs_conf}/autoload_configs/switch.conf.xml"
    local fw_bin; fw_bin="$(sa::bin ufw)"
    if [[ -n "${fs_conf}" && -r "${sw_conf}" ]] && [[ -n "${fw_bin}" ]]; then
        local rtp_lo rtp_hi
        rtp_lo="$(grep -oP 'rtp-start-port"\s+value="\K[0-9]+' "${sw_conf}" 2>/dev/null | head -1)"
        rtp_hi="$(grep -oP 'rtp-end-port"\s+value="\K[0-9]+' "${sw_conf}" 2>/dev/null | head -1)"
        if [[ -n "${rtp_lo}" && -n "${rtp_hi}" ]]; then
            # Any live RTP socket outside the configured range proves the running process is
            # not using the file's range, whatever the file says.
            #
            # Read the LOCAL port out of field 4 ONLY. An earlier version grepped every
            # ":<digits>" on the line, which also caught the PEER port — so FreeSWITCH's own
            # outbound DNS queries (ephemeral source port → 1.1.1.1:53) were reported as RTP
            # bound outside the range. Two false alarms on a perfectly healthy box, on the
            # first run after this check started working as root.
            #
            # Peer port 53 is skipped for the same reason: a connected DNS socket's local port
            # is ephemeral by definition and says nothing about the RTP allocator.
            #
            # `ss -p` needs root to attach process names. Without it the freeswitch filter
            # matches NOTHING, and the old code then printed "within range" having examined
            # zero sockets — a false clean, which is the worst result an audit can produce. So
            # it goes through sa::sudo and reports honestly when it cannot see.
            local ss_out; ss_out="$(sa::sudo ss -unap 2>/dev/null | grep -F 'freeswitch')"
            if [[ -z "${ss_out}" ]]; then
                sa::skip "RTP port range (ss needs root to map sockets to freeswitch)"
            else
            local -a out_of_range
            out_of_range=( ${(f)"$(print -r -- "${ss_out}" \
                | awk -v lo="${rtp_lo}" -v hi="${rtp_hi}" '
                    { lp = $4; sub(/.*:/, "", lp)
                      pp = $5; sub(/.*:/, "", pp)
                      if (lp !~ /^[0-9]+$/)         next
                      if (pp == "53")               next
                      if (lp == 5060 || lp == 5080) next
                      if (lp < lo || lp > hi)       print lp }' | sort -un)"} )
            out_of_range=( ${out_of_range:#} )
            if (( ${#out_of_range} )); then
                sa::warn "RTP bound outside the configured ${rtp_lo}-${rtp_hi} range: ${(j:, :)out_of_range[1,8]}"
                sa::fix "config says ${rtp_lo}-${rtp_hi} but the RUNNING process disagrees — rtp-*-port is read at startup only, so restart FreeSWITCH"
            else
                sa::ok "RTP ports within the configured ${rtp_lo}-${rtp_hi} range"
            fi
            fi  # ss_out non-empty
            # And the firewall has to allow that range, or in-range RTP is dropped instead.
            if ! sa::sudo "${fw_bin}" status 2>/dev/null | grep -qF "${rtp_lo}:${rtp_hi}/udp"; then
                sa::warn "ufw has no ${rtp_lo}:${rtp_hi}/udp allow rule matching the RTP range"
                sa::fix "ufw allow ${rtp_lo}:${rtp_hi}/udp   # a mismatch shows up as one-way audio, never as an error"
            fi
        fi
    fi
}

# Config files edited AFTER the service that reads them last started.
#
# This is the generic form of failure pattern 2, and the cheapest possible test for it. Where
# the per-service checks compare one known setting against its running value, this needs no
# knowledge of any setting at all: if the file is newer than the process, the running process
# cannot be using it, whatever it says.
#
# It is worth its own check because the fix looks complete when it is not. Someone edits the
# config, reads it back, sees the right value, and moves on — while the daemon keeps running
# on the old one indefinitely. Nothing warns, nothing errors, and `systemctl is-active` is
# perfectly happy.
#
# Three real instances on one host on 2026-09-13, all invisible until they were looked for:
#   - switch.conf.xml rtp-end-port corrected 65534 -> 32768 six days after FreeSWITCH last
#     started. Live RTP kept binding above the firewall's allowed range. The symptom of that
#     is intermittent one-way audio, which never appears in any log.
#   - event_socket.conf.xml listen-ip set to 127.0.0.1 in the same edit; the socket stayed
#     bound to 0.0.0.0.
#   - Both had sat that way for a month, and would have been applied silently and mid-call by
#     the next certbot renewal, which restarts FreeSWITCH from a deploy hook.
#
# WHAT THIS CANNOT SEE, and why it is still worth having.
#
# An OUT-OF-BAND reload is invisible here. `fail2ban-client reload`, `nginx -s reload` and
# `fs_cli -x reloadxml` all make the daemon re-read its config without telling systemd, and
# none of ActiveEnterTimestamp, StateChangeTimestamp or ExecMainStartTimestamp move when they
# run. So a service that WAS correctly reloaded still reports here.
#
# That is why the wording is "newer than the running process" and the fix is "confirm the
# running value matches", not "this is broken, restart it". The check answers one question
# honestly — is the file newer than the process — and leaves the conclusion to whoever knows
# whether a reload happened.
#
# It is still worth having because the expensive failure is the opposite one: nobody reloaded
# anything, everybody believes the edit is live, and it sits inert for months. And for
# FreeSWITCH specifically a reload genuinely is not enough — rtp-start-port, rtp-end-port and
# event_socket listen-ip are read at startup only, so `reloadxml` reports success and changes
# nothing.
#
# Reports the file and the age gap; never reloads anything. Reloading a daemon because a file
# looks newer is precisely the kind of unattended action that turns an audit into an outage.
function sa::audit_config_drift() {
    (( ${+commands[systemctl]} )) || return 0

    # unit : config directory. Only pairs where the daemon reads the directory at STARTUP are
    # useful here — a service that hot-reloads its config on change would report false drift.
    local -a pairs=(
        "nginx:/etc/nginx"
        "php-fpm:/etc/php"
        "postgresql:/etc/postgresql"
        "mariadb:/etc/mysql"
        "redis-server:/etc/redis"
        "supervisor:/etc/supervisor"
        "fail2ban:/etc/fail2ban"
    )

    # FreeSWITCH is added separately because its config directory is not a constant — a
    # source build, a Debian package and a `-conf <dir>` override all put it somewhere
    # different, so the running switch is asked instead of guessed. Falls back to the Debian
    # default only when fs_cli cannot answer (switch down, socket wedged).
    if (( ${+commands[fs_cli]} )) && sa::unit_active freeswitch; then
        local fs_conf_dir; fs_conf_dir="$(sa::fs_dir conf_dir)"
        [[ -d "${fs_conf_dir}" ]] || fs_conf_dir=/etc/freeswitch
        [[ -d "${fs_conf_dir}" ]] && pairs=( "freeswitch:${fs_conf_dir}" ${pairs} )
    fi

    # Every local is declared ONCE, here, and only assigned inside the loop. `local x` on a
    # name that already holds a value makes zsh PRINT it, so re-declaring inside the loop
    # leaks "count=4" style lines into the report from the second iteration onward.
    local -a drifted
    local pair unit conf_dir started started_epoch newer count age_note f
    local -i up_days
    for pair in "${pairs[@]}"; do
        unit="${pair%%:*}"
        conf_dir="${pair#*:}"
        [[ -d "${conf_dir}" ]] || continue
        sa::unit_active "${unit}" || continue

        started="$(systemctl show "${unit}" -p ActiveEnterTimestamp --value 2>/dev/null)"
        [[ -n "${started}" ]] || continue
        started_epoch="$(date -d "${started}" +%s 2>/dev/null)" || continue
        [[ "${started_epoch}" == <-> ]] || continue

        # -newermt on the unit's start time. Excludes the noise that is always newer and never
        # meaningful: VCS metadata, editor leftovers, and the .bak files these edits generate.
        newer="$(find "${conf_dir}" -type f \( -name '*.conf' -o -name '*.xml' -o -name '*.ini' -o -name '*.yaml' -o -name '*.yml' \) \
            -newermt "@${started_epoch}" \
            -not -path '*/.git/*' -not -name '*.bak*' -not -name '*~' -not -name '*.dpkg-*' \
            -printf '%p\n' 2>/dev/null | head -5)"
        [[ -n "${newer}" ]] || continue

        count="$(print -r -- "${newer}" | grep -c .)"
        # sa::human formats BYTES, not seconds — spell the uptime out rather than borrow it.
        up_days=$(( ( $(date +%s) - started_epoch ) / 86400 ))
        age_note=""
        (( up_days > 0 )) && age_note="process is ${up_days}d old" || age_note="edited after it started"
        drifted+=( "${unit}" )
        sa::warn "${unit}: ${count} config file(s) newer than the running process — ${age_note}"
        for f in ${(f)newer}; do sa::item "${f}"; done
        sa::fix "confirm the running value matches, then if not: systemctl restart ${unit}"
    done

    sa::metric "config_drift_units" ${#drifted}
    (( ${#drifted} )) || sa::ok "no service config edited since its process started"
}

function sa::audit_pm2() {
    (( ${+commands[pm2]} )) || return 0
    sa::hdr "PM2"
    local out; out="$(pm2 jlist 2>/dev/null)"
    [[ "${out}" == \[* ]] || { sa::skip "pm2 process list"; return 0 }

    # python3 rather than jq: jq is not installed on every one of these boxes, python3 is.
    local summary
    summary="$(print -r -- "${out}" | python3 -c '
import json,sys
try: procs = json.load(sys.stdin)
except Exception: sys.exit(1)
bad = [p["name"] for p in procs if p.get("pm2_env",{}).get("status") != "online"]
hot = [f''{p["name"]}={p.get("pm2_env",{}).get("restart_time",0)}'' for p in procs
       if (p.get("pm2_env",{}).get("restart_time") or 0) >= 5]
print(len(procs)); print(",".join(bad)); print(",".join(hot))
' 2>/dev/null)"
    [[ -n "${summary}" ]] || { sa::skip "pm2 process list"; return 0 }
    local -a lines=( ${(f)summary} )
    local total="${lines[1]}" bad="${lines[2]}" hot="${lines[3]}"
    [[ -n "${bad}" ]] && { sa::warn "pm2 process(es) not online: ${bad}"; sa::fix "pm2 logs <name> --err --lines 50" } \
                      || sa::ok "all ${total} pm2 process(es) online"
    [[ -n "${hot}" ]] && sa::warn "pm2 process(es) restarting repeatedly: ${hot}"
}

# WireGuard is the purest instance of failure pattern 1 on this list.
#
# When a peer stops handshaking the interface stays up, its routes stay installed, and
# `systemctl is-active wg-quick@wg0` stays green — traffic for that peer simply goes
# nowhere. Nothing is logged, because from the kernel's point of view nothing failed. The
# only evidence is handshake age and the byte counters, so this reads those directly and
# never infers health from unit state.
function sa::audit_wireguard() {
    local wg; wg="$(sa::bin wg)" || return 0
    sa::hdr "WireGuard"

    # `wg show` pulls key material out of the kernel and is root-only. Run unprivileged it
    # exits 0 having printed nothing at all — indistinguishable from "no interfaces
    # configured", which is the silent-coverage failure sa::bin exists to prevent.
    local dump; dump="$(sa::sudo "${wg}" show all dump 2>/dev/null)"
    [[ -n "${dump}" ]] || { sa::skip "wg peer state"; return 0 }

    # `wg show all dump` is tab-separated in two shapes: an INTERFACE line of 5 fields
    # (name, private key, public key, listen port, fwmark) and a PEER line of 9 (name,
    # public key, preshared key, endpoint, allowed-ips, last handshake, rx, tx, keepalive).
    # Field COUNT is the only reliable discriminator — a peer legitimately carries "(none)"
    # in several columns, so matching on content would misclassify.
    local -a iface_names=() never=() stale=() silent=() route_ifaces=()
    local -A iface_port=()
    local -i peers=0 now=${EPOCHSECONDS}
    local -a f=()

    while IFS=$'\t' read -r -A f; do
        if (( ${#f} == 5 )); then
            iface_names+=( "${f[1]}" ); iface_port[${f[1]}]="${f[4]}"
        elif (( ${#f} == 9 )); then
            (( peers++ ))
            local ifn="${f[1]}" pub="${f[2]}" aips="${f[5]}" ka="${f[9]}"
            local tag="${pub:0:8}"
            local -i hs=${f[6]} rx=${f[7]} tx=${f[8]} age=0
            (( hs > 0 )) && age=$(( now - hs ))

            # A peer whose AllowedIPs is a subnet rather than a single /32 is routed
            # THROUGH this host, which only works when ip_forward is on. Checked below,
            # but only when such a peer actually exists — warning about forwarding on a
            # pure client box would be noise.
            [[ "${aips}" == */* && "${aips}" != */32* ]] && route_ifaces+=( "${ifn}" )

            if (( hs == 0 )); then
                never+=( "${ifn}/${tag}" )
            elif (( age > 300 )) && [[ "${ka}" != off ]]; then
                # persistent-keepalive is set, so this peer SHOULD re-handshake every
                # couple of minutes. Silence is a dead tunnel, not an idle one.
                stale+=( "${ifn}/${tag} last handshake ${age}s ago" )
            elif (( rx == 0 || tx == 0 )); then
                # Handshaking but one direction has never carried a byte: usually an
                # AllowedIPs or routing mistake rather than a connectivity failure.
                silent+=( "${ifn}/${tag} rx=$(sa::human ${rx}) tx=$(sa::human ${tx})" )
            fi
        fi
    done <<< "${dump}"

    sa::metric "wg_peers" ${peers}
    sa::metric "wg_peers_broken" $(( ${#never} + ${#stale} ))

    local p=""
    if (( ${#never} )); then
        sa::warn "${#never} wg peer(s) have NEVER completed a handshake"
        for p in "${never[@]}"; do sa::item "${p}"; done
        sa::fix "verify the peer's endpoint and public key, and that UDP reaches this host"
    fi
    if (( ${#stale} )); then
        sa::warn "${#stale} wg peer(s) with keepalive set have stopped handshaking"
        for p in "${stale[@]}"; do sa::item "${p}"; done
        sa::fix "check the far end and the NAT/UDP path; the tunnel is down despite looking up"
    fi
    if (( ${#silent} )); then
        sa::info "${#silent} wg peer(s) handshaking but carrying no traffic one way"
        for p in "${silent[@]}"; do sa::item "${p}"; done
    fi
    (( ${#never} + ${#stale} )) || sa::ok "all ${peers} wg peer(s) handshaking"

    # Every `local` below carries an explicit assignment, including the empty ones. zsh
    # PRINTS "name=value" when typeset re-declares a parameter that already holds one and
    # no new value is given — and these names are all set earlier, in the peer loop or on a
    # previous iteration. A bare `local ifn` here leaked "ifn=wg0" onto stdout.
    local ifn=""
    for ifn in "${iface_names[@]}"; do
        # wg-quick@ is what survives a reboot. An interface brought up by hand works
        # perfectly right up until the box restarts, and is then simply gone.
        if (( ${+commands[systemctl]} )) && ! systemctl is-enabled --quiet "wg-quick@${ifn}" 2>/dev/null; then
            sa::warn "wg-quick@${ifn} not enabled — ${ifn} will not return after a reboot"
            sa::fix "systemctl enable wg-quick@${ifn}"
        fi

        # A tunnel MTU left at the underlay's 1500 fragments every full-size packet. It
        # presents as "small requests fine, large ones hang" and never as an error.
        local mtu="$(ip -o link show "${ifn}" 2>/dev/null | grep -oE 'mtu [0-9]+' | awk '{print $2}')"
        if [[ -n "${mtu}" ]] && (( mtu > 1440 )); then
            sa::warn "${ifn} MTU is ${mtu} — high for a tunnel; large packets may hang while small ones succeed"
            sa::fix "set MTU = 1420 under [Interface] in /etc/wireguard/${ifn}.conf"
        fi

        # The listen port must be reachable or no peer can ever handshake inbound. Only
        # meaningful once ufw is actually enforcing; an inactive ufw is audit_firewall's
        # finding to report, not this one's.
        # NOT named `status`: that is one of zsh's read-only special parameters (an alias
        # for $?), so assigning to it aborts the function with "read-only variable".
        local port="${iface_port[${ifn}]}" ufw="" ufw_status=""
        if [[ -n "${port}" && "${port}" != 0 ]] && ufw="$(sa::bin ufw)"; then
            ufw_status="$(sa::sudo "${ufw}" status 2>/dev/null)"
            if [[ "${ufw_status}" == *'Status: active'* ]] && ! print -r -- "${ufw_status}" | grep -qE "^${port}(/udp)?[[:space:]]"; then
                sa::warn "${ifn} listens on UDP ${port} but ufw has no rule for it"
                sa::fix "ufw allow ${port}/udp comment 'WireGuard ${ifn}'"
            fi
        fi
    done

    if (( ${#route_ifaces} )); then
        local fwd; fwd="$(sysctl -n net.ipv4.ip_forward 2>/dev/null)"
        if [[ "${fwd}" != 1 ]]; then
            sa::warn "peers route subnets through this host but net.ipv4.ip_forward=${fwd:-unset}"
            sa::fix "echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-wg-forward.conf && sudo sysctl --system"
        fi
    fi
}

function sa::audit_docker() {
    (( ${+commands[docker]} )) || return 0
    docker info &>/dev/null || sa::sudo docker info &>/dev/null || return 0
    sa::hdr "Docker"

    local -a dk=( docker ); docker info &>/dev/null || dk=( sudo docker )
    local unhealthy; unhealthy="$("${dk[@]}" ps --filter health=unhealthy --format '{{.Names}}' 2>/dev/null)"
    local -a un=( ${(f)unhealthy} ); un=( ${un:#} )
    (( ${#un} )) && { sa::warn "unhealthy container(s): ${(j:, :)un}" } || sa::ok "no unhealthy containers"
    sa::metric "docker_unhealthy" ${#un}

    # Containers restarting in a loop present as "Up 3 seconds" forever.
    local -a loop=( ${(f)"$("${dk[@]}" ps --format '{{.Names}} {{.Status}}' 2>/dev/null | awk '/Restarting/ {print $1}')"} )
    loop=( ${loop:#} )
    (( ${#loop} )) && sa::warn "container(s) stuck restarting: ${(j:, :)loop}"

    local reclaim
    # "Build Cache 43.38MB (100%)" — the type is two words, so take the size field by
    # position from the end rather than counting from the front.
    reclaim="$("${dk[@]}" system df --format '{{.Type}} {{.Reclaimable}}' 2>/dev/null | awk '/^Build/ {print $3}')"
    [[ -n "${reclaim}" ]] && sa::info "build cache reclaimable: ${reclaim}"
}

function sa::audit_mail() {
    local depth=""
    if (( ${+commands[exim4]} )); then
        depth="$(sa::sudo exim4 -bpc 2>/dev/null)"
    elif (( ${+commands[postqueue]} )); then
        depth="$(sa::sudo postqueue -p 2>/dev/null | tail -1 | grep -oE '[0-9]+' | head -1)"
    else
        return 0
    fi
    sa::hdr "Mail queue"
    if [[ "${depth}" == <-> ]]; then
        sa::metric "mail_queue" "${depth}"
        (( depth > 50 )) && { sa::warn "${depth} message(s) queued"; sa::fix "exim4 -bp | head -20" } \
                         || sa::ok "${depth} message(s) queued"
    else
        sa::skip "mail queue depth"
    fi
}

function sa::audit_firewall() {
    # Resolved rather than tested with ${+commands[ufw]}: ufw lives in /usr/sbin, so that
    # test is false for every non-root run and this whole section silently did nothing.
    local ufw_bin; ufw_bin="$(sa::bin ufw)" || return 0
    sa::hdr "Firewall (UFW)"
    local st; st="$(sa::sudo "${ufw_bin}" status verbose 2>/dev/null)"
    if [[ -z "${st}" ]]; then sa::skip "UFW status"; return 0; fi
    if [[ "${st}" == *'Status: active'* ]]; then
        # Array first, then subscript — same trap as the jail list in sa::audit_fail2ban.
        # A `:#` filter nested inside ${...} does not survive being subscripted: written as
        # ${${(M)${(f)st}:#Default:*}[1]} this silently produced an EMPTY string, so the
        # default policy - the single most important fact about a firewall - was dropped from
        # the report and the line read as a bare "active". Note that ${${(z)x}[1]} and
        # ${${(f)x}[1]} DO work; it is specifically the filter form that does not.
        local -a def_lines=( ${(M)${(f)st}:#Default:*} )
        local def="${def_lines[1]}"
        sa::ok "active${def:+ — ${def}}"
    else
        sa::warn "UFW is INACTIVE — the host is unfirewalled"
        sa::fix "sudo ufw enable   (confirm your SSH port is allowed first)"
    fi
}

function sa::audit_fail2ban() {
    (( ${+commands[fail2ban-client]} )) || return 0
    sa::hdr "Fail2Ban"
    local st; st="$(sa::sudo fail2ban-client status 2>/dev/null)"
    if [[ -z "${st}" ]]; then sa::skip "Fail2Ban jail status"; return 0; fi

    # The matching line is captured into an ARRAY before it is subscripted. Writing this as
    # one nested expansion - ${${(M)${(f)st}:#*Jail list:*}[1]} - looks equivalent and is not:
    # the [1] is applied to the joined SCALAR, so it returned the first CHARACTER of the whole
    # output ("S", from "Status") rather than the first matching line. Everything downstream
    # then worked perfectly on garbage: the jail count was reported as 1 no matter how many
    # jails existed, and the per-jail loop queried a jail named "S", so fail2ban_banned was
    # always 0 and its run-over-run delta could never fire.
    local -a jail_lines=( ${(M)${(f)st}:#*Jail list:*} )
    (( ${#jail_lines} )) || { sa::skip "Fail2Ban jail list (unrecognised status output)"; return 0 }
    local csv="${jail_lines[1]##*:}"
    local -a jails=( ${(s:,:)csv} ); jails=( ${jails//[[:space:]]/} ); jails=( ${jails:#} )
    sa::ok "daemon active — ${#jails} jail(s)"
    local j js banned
    local -i total=0
    for j in "${jails[@]}"; do
        js="$(sa::sudo fail2ban-client status "${j}" 2>/dev/null)"
        banned="$(print -r -- "${js}" | grep -oP 'Currently banned:\s*\K[0-9]+')"
        [[ "${banned}" == <-> ]] && (( total += banned ))
    done
    sa::metric "fail2ban_banned" "${total}"
    sa::info "${total} address(es) currently banned across all jails"
}

function sa::audit_certs() {
    (( ${+commands[certbot]} )) || return 0
    sa::hdr "TLS certificates"
    if (( ${+commands[systemctl]} )); then
        local te ta
        te="$(systemctl is-enabled certbot.timer 2>/dev/null)"
        ta="$(systemctl is-active certbot.timer 2>/dev/null)"
        [[ "${te}" == enabled && "${ta}" == active ]] \
            && sa::ok "certbot.timer enabled and active" \
            || sa::warn "certbot.timer is ${te:-unavailable}/${ta:-inactive} — renewals may not run"
        local res; res="$(systemctl show certbot.service -p Result --value 2>/dev/null)"
        [[ -n "${res}" && "${res}" != success ]] && sa::warn "last certbot run result: ${res}"
    fi

    local certs
    certs="$(sa::sudo certbot certificates 2>/dev/null)"
    if [[ -z "${certs}" ]]; then sa::skip "certificate expiry"; return 0; fi

    local -a expiring=() expired=()
    local name days line
    while IFS= read -r line; do
        [[ "${line}" == *'Certificate Name:'* ]] && name="${line##*: }"
        if [[ "${line}" == *'Expiry Date:'* ]]; then
            if [[ "${line}" == *INVALID* || "${line}" == *EXPIRED* ]]; then
                expired+=( "${name}" )
            else
                days="${${line##*VALID: }%% days*}"
                [[ "${days}" == <-> && ${days} -le 30 ]] && expiring+=( "${name}=${days}d" )
            fi
        fi
    done <<< "${certs}"

    local -i count=$(print -r -- "${certs}" | grep -c 'Certificate Name:')
    sa::metric "certs_expiring_30d" ${#expiring}
    (( ${#expired} ))  && { sa::warn "${#expired} EXPIRED certificate(s): ${(j:, :)expired}"; sa::fix "sudo certbot renew --cert-name <name>" }
    (( ${#expiring} )) && sa::warn "${#expiring} certificate(s) expiring within 30 days: ${(j:, :)expiring}"
    (( ${#expired} == 0 && ${#expiring} == 0 )) && sa::ok "${count} certificate(s), none expiring within 30 days"
}

# Pattern 3: unbounded growth. Two separate failures — a file that is simply enormous, and
# a file that no logrotate rule covers (which is why it became enormous).
function sa::audit_logs() {
    [[ -d /var/log ]] || return 0
    sa::hdr "Log growth"

    local -a roots=( /var/log )
    [[ -d /var/www ]] && roots+=( /var/www )
    [[ -d /srv ]] && roots+=( /srv )

    local -a big=()
    # lpath, never `path`: zsh ties `path` to $PATH and `local path` keeps the tie,
    # so assigning to it wipes PATH for the rest of the function. The symptom is not an
    # error — every external command silently fails to resolve. Here that emptied `cat` of
    # the logrotate rules, which then made 27 perfectly-covered logs report as uncovered.
    local line sz lpath
    while IFS= read -r line; do
        [[ -n "${line}" ]] || continue
        sz="${line%% *}"; lpath="${line#* }"
        big+=( "${lpath} ($(sa::human ${sz}))" )
    done < <(sa::sudo find "${roots[@]}" -xdev -type f \( -name '*.log' -o -name '*.log.[0-9]' \) \
                -size +$(( SERVICE_AUDIT_LOG_MAX_BYTES / 1024 ))k -printf '%s %p\n' 2>/dev/null | sort -rn | head -10)

    if (( ${#big} )); then
        sa::warn "${#big} log file(s) over $(sa::human ${SERVICE_AUDIT_LOG_MAX_BYTES})"
        local b; for b in "${big[@]}"; do sa::item "${b}"; done
        sa::fix "review, then: sudo truncate -s 0 <path>"
    else
        sa::ok "no log file over $(sa::human ${SERVICE_AUDIT_LOG_MAX_BYTES})"
    fi

    # Coverage: a live .log in /var/log with no logrotate rule naming its directory is the
    # shape that produces a 10GB file. Matching on the directory rather than the exact file
    # keeps wildcard rules (/var/log/nginx/*.log) from reading as misses.
    if [[ -d /etc/logrotate.d ]]; then
        local -a rules=( /etc/logrotate.d/*(N.) )
        local rule_text; rule_text="$(cat "${rules[@]}" /etc/logrotate.conf 2>/dev/null)"
        # A missing logrotate rule only matters if something is actually accumulating.
        # Plenty of programs prune their own logs — this repo's own scripts/memwatch deletes
        # anything past RETAIN_DAYS — and reporting those as unrotated produced 14 findings
        # about files totalling a few hundred KB. A check that fires on healthy state is a
        # check you stop reading, so the rule is: no logrotate coverage AND real size, either
        # in one file or accumulated across the directory.
        local -i uncov_file_min=$(( 10 * 1024 * 1024 ))
        local -i uncov_dir_min=$(( 50 * 1024 * 1024 ))
        local -A dir_bytes=()
        local -a candidates=() uncovered=()
        local lg d
        local -i sz

        # zstat, not `stat -c %s … || fallback`: the command-substitution-plus-|| form leaks
        # an empty assignment into the output when the file cannot be read, and this is a
        # builtin the repo already relies on elsewhere.
        zmodload -F zsh/stat b:zstat 2>/dev/null

        for lg in /var/log/*.log(N.) /var/log/*/*.log(N.); do
            d="${lg:h}"
            [[ "${rule_text}" == *"${lg}"* || "${rule_text}" == *"${d}/"* ]] && continue
            candidates+=( "${lg}" )
            sz=$(zstat +size "${lg}" 2>/dev/null)
            dir_bytes[${d}]=$(( ${dir_bytes[${d}]:-0} + sz ))
        done

        for lg in "${candidates[@]}"; do
            d="${lg:h}"
            sz=$(zstat +size "${lg}" 2>/dev/null)
            (( sz >= uncov_file_min || ${dir_bytes[${d}]:-0} >= uncov_dir_min )) && uncovered+=( "${lg}" )
        done

        # Mutually exclusive, and in severity order — an earlier version printed both the
        # "small or self-pruned" note and "every file is covered", which flatly contradict.
        if (( ${#uncovered} )); then
            sa::warn "${#uncovered} log file(s) with no logrotate rule and real size"
            local u; for u in "${uncovered[@]:0:8}"; do sa::item "${u}"; done
            sa::fix "add a rule under /etc/logrotate.d/"
        elif (( ${#candidates} )); then
            sa::ok "${#candidates} log file(s) have no logrotate rule, but are small or self-pruned"
        else
            sa::ok "every /var/log file is covered by a logrotate rule"
        fi
    fi
}

function sa::audit_storage() {
    sa::hdr "Storage"

    # Inodes, which the space report never covers. Exhaustion presents as "no space left"
    # with plenty of free bytes, and is baffling if you have not hit it before.
    # Only real block devices. WSL alone mounts a dozen pseudo-filesystems that each report
    # the same meaningless 1%, and a report padded with eleven identical ✓ lines is one
    # nobody reads to the end of.
    local line fs pct mount
    local -i checked=0
    while IFS= read -r line; do
        fs="${${(z)line}[1]}"; pct="${${(z)line}[5]}"; mount="${${(z)line}[6]}"
        [[ "${fs}" == /dev/* ]] || continue
        [[ "${pct%\%}" == <-> ]] || continue
        (( checked++ ))
        (( ${pct%\%} >= 85 )) && { sa::warn "inodes ${pct} used on ${mount}"; sa::fix "find <path> -xdev -type f | wc -l   # locate the small-file sprawl" }
    done < <(command df -iP 2>/dev/null | tail -n +2)
    (( checked )) && sa::ok "inode usage healthy on ${checked} filesystem(s)"

    # fstab entries whose device is gone: the mount silently does not happen at boot, and
    # whatever writes there fills the root filesystem instead.
    if [[ -r /etc/fstab ]]; then
        local -a missing=()
        local spec mp rest
        while read -r spec mp rest; do
            [[ "${spec}" == \#* || -z "${spec}" ]] && continue
            [[ "${mp}" == (none|swap) ]] && continue
            case "${spec}" in
                (UUID=*)   [[ -e "/dev/disk/by-uuid/${spec#UUID=}" ]]   || missing+=( "${spec} → ${mp}" ) ;;
                (LABEL=*)  [[ -e "/dev/disk/by-label/${spec#LABEL=}" ]] || missing+=( "${spec} → ${mp}" ) ;;
                (/dev/*)   [[ -e "${spec}" ]]                           || missing+=( "${spec} → ${mp}" ) ;;
            esac
        done < /etc/fstab
        (( ${#missing} )) && { sa::warn "${#missing} fstab entry/entries whose device is absent"; local m; for m in "${missing[@]}"; do sa::item "${m}"; done }
    fi
}

function sa::audit_time() {
    (( ${+commands[timedatectl]} )) || return 0
    local synced; synced="$(timedatectl show -p NTPSynchronized --value 2>/dev/null)"
    [[ -n "${synced}" ]] || return 0
    sa::hdr "Time synchronisation"
    [[ "${synced}" == yes ]] && sa::ok "clock is NTP-synchronised" \
                             || sa::warn "clock is NOT NTP-synchronised — TLS and log correlation will suffer"
}

function sa::audit_reboot() {
    [[ -f /var/run/reboot-required ]] || return 0
    sa::hdr "Pending reboot"
    sa::warn "REBOOT REQUIRED"
    [[ -f /var/run/reboot-required.pkgs ]] && \
        sa::item "packages: $(head -10 /var/run/reboot-required.pkgs | tr '\n' ' ')"

    # Services still running against libraries that have been replaced on disk. This is the
    # other half of pattern 2 — the upgrade landed, the process never picked it up.
    if (( ${+commands[needrestart]} )); then
        local out; out="$(sa::sudo env DEBIAN_FRONTEND=noninteractive needrestart -b 2>/dev/null)"
        local svc; svc="$(print -r -- "${out}" | grep -oP '^NEEDRESTART-SVC:\s*\K\S+' | tr '\n' ' ')"
        [[ -n "${svc}" ]] && { sa::warn "services running against replaced libraries: ${svc}"; sa::fix "sudo needrestart -r a" }
    fi
}

# ---------------------------------------------------------------------------------------

function service_audit::usage() {
    print -r -- "Usage: service-audit [-h|--help] [--quiet] [--no-prompt]"
    print -r -- ""
    print -r -- "Audit whatever services this machine actually runs. Every check is gated on"
    print -r -- "the thing it inspects existing, so the same command is safe to run on a WSL"
    print -r -- "dev box, a desktop, or any server — it audits what it finds and stays silent"
    print -r -- "about the rest."
    print -r -- ""
    print -r -- "Covers: systemd units (including restart-loops that stay 'active'), nginx,"
    print -r -- "MariaDB/MySQL, PostgreSQL, Redis, PHP-FPM, Supervisor, FreeSWITCH, PM2,"
    print -r -- "Docker, mail queue, UFW, Fail2Ban, TLS certificates, log growth and rotation"
    print -r -- "coverage, inodes and fstab, time sync, and pending reboots."
    print -r -- ""
    print -r -- "Counters that only mean something as a trend — 5xx totals, journal errors,"
    print -r -- "queue depth, restart counts — are stored between runs and reported as deltas."
    print -r -- "State: \${XDG_STATE_HOME:-~/.local/state}/service-audit/state"
    print -r -- ""
    print -r -- "REPORTS ONLY. It never restarts, truncates, or deletes anything; each finding"
    print -r -- "is printed with the command that would fix it."
    print -r -- ""
    print -r -- "Options:"
    print -r -- "  --quiet      Only the verdict line."
    print -r -- "  --no-prompt  Never ask for a password. An ALREADY-CACHED sudo credential is"
    print -r -- "               still used, so this is not the same as running unprivileged;"
    print -r -- "               what it guarantees is that the audit cannot block waiting for"
    print -r -- "               input. Checks that then cannot run are skipped and named."
}

function service_audit() {
    emulate -L zsh
    setopt local_options null_glob extended_glob

    local quiet=0 arg
    local -i sa_sudo_ok=0 sa_sudo_prompt=1
    for arg in "$@"; do
        case "${arg}" in
            (-h|--help)  service_audit::usage; return 0 ;;
            (--quiet)    quiet=1 ;;
            (--no-prompt) sa_sudo_prompt=0 ;;
            (*) print -ru2 -- "service-audit: unknown option '${arg}'"; return 2 ;;
        esac
    done

    local -a sa_findings=() sa_skipped=()
    local -A sa_metrics=()
    zmodload -F zsh/datetime p:EPOCHSECONDS 2>/dev/null

    # Called directly, NEVER through a pipe. zsh runs every element of a pipeline except the
    # last in a subshell, so `{ …audits… } | cat` would discard sa_findings and sa_metrics
    # the moment the block ended — the verdict would always read clean and the state file
    # would never gain a counter. --quiet is handled inside the print helpers instead.
    sa::audit_systemd
    sa::audit_config_drift
    sa::audit_reboot
    sa::audit_nginx
    sa::audit_phpfpm
    sa::audit_mysql
    sa::audit_postgres
    sa::audit_redis
    sa::audit_supervisor
    sa::audit_freeswitch
    sa::audit_pm2
    sa::audit_wireguard
    sa::audit_docker
    sa::audit_mail
    sa::audit_firewall
    sa::audit_fail2ban
    sa::audit_certs
    sa::audit_logs
    sa::audit_storage
    sa::audit_time
    sa::report_deltas

    if (( ${#sa_skipped} )); then
        print -r -- ""
        print -r -- "    ℹ️ ${#sa_skipped} check(s) skipped for lack of root: ${(j:, :)sa_skipped}"
    fi

    if (( ${#sa_findings} )); then
        print -r -- "${#sa_findings} service finding(s) require review"
    else
        print -r -- "Services clean — nothing requires review"
    fi
    return $(( ${#sa_findings} > 0 ))
}

alias service-audit="service_audit"
