#!/usr/bin/env zsh
# ==============================================================================
# maintain.zsh - Full-spectrum system maintenance
# ==============================================================================
# Defines `maintain` (alias: `update-all`) plus its ::run / ::usage / ::path_dupes
# helpers. Extracted from aliases.zsh: a six-phase maintenance system with log
# rotation and a bootstrap prompt is a subsystem, not an alias.
#
# Sourced by: .zshrc, via the `${ZDOTDIR}/functions/`*.zsh(N) loop
#
# The .zsh extension is load-bearing — that loop globs *.zsh, so a .sh file would
# be skipped silently, with `update-all: command not found` as the only symptom.
#
# The loop runs AFTER aliases.zsh, which is safe: nothing here resolves through an
# alias. The zinit step invokes functions/zinit-reset by path on purpose, because
# zsh expands aliases at function-definition time and any future reordering would
# otherwise break it without a word.
# ==============================================================================

# Full-spectrum system maintenance in one pass — not just an updater. It UPDATES system
# packages, shell/editor/tmux plugins, and language toolchains; CLEANS caches, old kernels,
# coredumps, snap revisions, and dev caches; FIXES by tightening secret-file permissions and
# recompiling zsh; and VERIFIES via broken-symlink, dotfiles-drift, config-merge, security,
# and disk-usage audits. Supersedes the old `update-all` (kept as an alias below).
# The install.sh bootstrap and the ~400MB zinit reset are opt-in (prompted, or forced with
# --install / --zinit); everything else runs by default.
#
# Each step is independent and self-guarded: a missing tool is skipped, and a step that
# fails is recorded rather than aborting the run. A summary at the end lists reclaimed
# disk and any steps that failed (and the function returns non-zero if any did).
#
# Platform awareness (HOST_OS / HOST_LOCATION / IS_DEVCONTAINER from detect_os.sh):
#   - Runs on WSL, Ubuntu desktop, Ubuntu server, and macOS; brew steps cover Linuxbrew.
#   - Root shells work without sudo (sudo_cmd shim expands to nothing when EUID==0).
#   - Devcontainers skip OS-level steps (apt/snap/flatpak/fstrim/journal/trash/…).
#   - Servers get a read-only status report: reboot-required, failed systemd units,
#     services needing restart, journal error count. It never changes state.
#
# Destructive steps are conservative: trash/thumbnails only drop items older than 30
# days, and docker prune keeps volumes and anything younger than 7 days.
#
# Every run is tee'd to ${XDG_STATE_HOME}/logs/maintain/maintain-<timestamp>.log
# (10 newest kept) by the wrapper below.
#
# The zinit step is deliberately a full wipe+reinstall (zi-update above) and there is no
# in-place fast path, because `zinit update` replays the ices each plugin saved into
# <plugin>/._zinit/ at install time rather than the ones .zshrc declares now. That
# divergence is silent and unbounded: it is what kept rebuilding qsv/yazi from source
# after they were switched to prebuilt binaries, what kept updating plugins long since
# deleted from the config, and what hangs tj/git-extras forever on an invisible
# `read -p` prompt. It also only bites once an update actually pulls new commits, so it
# passes for weeks and then fails. Re-downloading ~400MB is the cheaper failure.
#
# If you knowingly want the fast path on a machine you just reset, run
# `zinit update --parallel` directly — don't wire it back in here as a default.

function maintain::usage() {
    print -r -- "Usage: maintain [-h|--help] [--install] [--zinit]"
    print -r -- ""
    print -r -- "Full-spectrum system maintenance — update, clean, fix, and verify — in six phases:"
    print -r -- "  1. System & OS package managers (brew/apt/pacman, flatpak, snap+cleanup, firmware/macOS updates)"
    print -r -- "  2. Runtimes & version managers (gh, zinit reset, vim-plug, tmux/TPM, Claude Code, mise, rustup, …)"
    print -r -- "  3. Global packages & language build caches (npm, pnpm, bun, uv, pipx, pynvim, composer, go, cargo, atuin sync)"
    print -r -- "  4. Container hygiene (docker/podman prune, safe mode)"
    print -r -- "  5. Cleanup & caches (TRIM, journal, coredumps, macOS/dev caches, DNS flush, zsh recompile, font/desktop DBs)"
    print -r -- "  6. Health, integrity & security (doctors, PATH shadows, broken-link & dotfiles audit, config-merge/security report, permission audit, disk report)"
    print -r -- ""
    print -r -- "Options:"
    print -r -- "  --install   Run the dotfiles install.sh bootstrap first (skips its prompt)."
    print -r -- "  --zinit     Reset & reinstall zinit plugins, ~400MB re-download (skips its prompt)."
    print -r -- ""
    print -r -- "Two steps are opt-in. Before the phases begin, maintain asks whether to run the"
    print -r -- "dotfiles install.sh bootstrap and whether to reset zinit plugins (both default N —"
    print -r -- "a bare Enter skips them). Each prompt is suppressed when its flag is passed, and"
    print -r -- "both are suppressed entirely when stdin is not a terminal, so scripted and cron"
    print -r -- "runs skip them unless --install / --zinit are given."
    print -r -- ""
    print -r -- "Primes sudo up front and keeps it alive so the run is unattended"
    print -r -- "(root shells run sudo-free). Devcontainers skip OS-level steps."
    print -r -- "Skips any tool that isn't installed; records (never aborts on) failures"
    print -r -- "and prints a summary of reclaimed disk plus any steps that failed."
    print -r -- "Every run is logged to \${XDG_STATE_HOME:-~/.local/state}/logs/maintain/ (10 kept)."
    print -r -- "The run itself executes in a subshell (it is piped to tee), so finish with"
    print -r -- "'exec zsh' to pick up updated command paths."
}

# Report commands that exist in more than one install location. This catches the failure
# mode where a tool installed two ways leaves the OLDER copy winning on PATH forever, in
# silence: a stale ~/.local/bin/gh 2.92.0 shadowed the zinit-managed 2.97.0 while maintain
# dutifully updated the copy that never ran. Nothing else in the run would surface that.
#
# Strictly read-only — it prints, and never reorders PATH or deletes anything.
#
# The allowlist is what makes this worth having, not a nicety. Without it the check reports
# 13 deliberate shadows on a perfectly healthy machine, and a report you learn to skip past
# is worse than no report because it still looks like coverage. Keep the list short and keep
# each reason attached: if one of those decisions changes — say mise stops owning vim, see
# mise/config.toml — the matching entries MUST come out, or they will mask real duplicates.
function maintain::path_dupes() {
    emulate -L zsh
    setopt local_options null_glob

    local -a expected=(
        vim view rvim rview ex vimdiff vimtutor xxd  # mise owns vim; plugins need 9.2
        python3 pydoc3 python3-config                # mise python shadows python3-minimal
        sg                                           # apt `login` beats ast-grep's stray sg
        install                                      # coreutils; a plugin dir leaks one
    )

    local d f c
    local -aU cands
    for d in ~/.local/share/mise/installs/*/*/bin(/N) ~/.local/share/zinit/plugins/*(/N) \
             ~/.local/share/zinit/polaris/bin(/N) ~/.cargo/bin(/N) \
             ~/.local/share/npm/bin(/N) ~/.config/bun/bin(/N) ~/.local/bin(/N); do
        for f in "${d}"/*(-*N); do cands+=( "${f:t}" ); done
    done

    local -a hits
    for c in ${(o)cands}; do
        (( ${expected[(Ie)${c}]} )) && continue
        local -aU locs reals
        locs=( ${(f)"$(whence -a -p -- ${c} 2>/dev/null)"} )
        (( ${#locs} > 1 )) || continue
        # Compare RESOLVED targets: /bin is a symlink to /usr/bin on Ubuntu, so the very
        # same file would otherwise be reported as a duplicate of itself on every box.
        reals=( ${locs[@]:A} )
        (( ${#reals} > 1 )) && hits+=( "      ${c}: ${(j: :)locs}" )
    done

    if (( ${#hits} )); then
        print -r -- "    ⚠️ Shadowed commands (first path wins; a newer copy may be masked):"
        print -rl -- "${hits[@]}"
    else
        print -r -- "    ✓ No unexpected duplicate executables on PATH"
    fi
}

# Wrapper: tee the whole run to a timestamped log (keeping the 10 newest), preserving
# the inner function's exit status through the pipe. `log_file` is a local here, and
# zsh's dynamic scoping lets maintain::run reference it in the summary block.
#
# Argument parsing lives HERE, ahead of the logging setup, so `maintain --help` doesn't
# mkdir a log dir, write a log containing nothing but the usage text, and rotate.
#
# Note the pipe: zsh runs only the LAST element of a pipeline in the current shell, so
# maintain::run executes in a subshell. Nothing it does to shell state — command hash,
# variables, cwd — survives back here. That is fine for every step (each one only shells
# out) but it is why the summary insists on `exec zsh` rather than merely suggesting it.
function maintain() {
    setopt local_options

    # run_install / run_zinit are locals here; zsh's dynamic scoping lets maintain::run read
    # them through the pipeline subshell, same as log_file below. A flag forces the step on
    # (no prompt); without it we ask on a tty (default N) and skip when non-interactive.
    local run_install=0
    local run_zinit=0
    local arg
    for arg in "$@"; do
        case "${arg}" in
            (-h|--help)
                maintain::usage
                return 0
                ;;
            (--install)
                run_install=1
                ;;
            (--zinit)
                run_zinit=1
                ;;
            (*)
                print -ru2 -- "maintain: unknown option '${arg}'"
                return 2
                ;;
        esac
    done

    # Two opt-in steps are asked HERE, not inside maintain::run: that function's stdout is the
    # tee pipe, and a prompt written into a pipe is exactly the trap that made the apt/debconf
    # dialog unsteerable. Up here stdout is still the terminal, and asking before the long
    # unattended phases start mirrors why sudo is primed up front — every question lands now,
    # not ten minutes in.
    #
    # ZDOTDIR is ~/.config/zsh, a symlink into the repo, so :A resolves it before :h takes the
    # parent — a bare ${ZDOTDIR:h} would look in ~/.config and miss.
    #
    # Default for both prompts is N: a bare Enter, EOF, or a non-tty stdin (cron, CI,
    # `maintain < /dev/null`) all mean skip. The matching --install / --zinit flags force the
    # step on and suppress its prompt, so scripted runs stay fully unattended.
    local install_script="${ZDOTDIR:A:h}/install.sh"
    if (( ! run_install )) && [[ -t 0 && -r "${install_script}" ]]; then
        local reply=""
        read -r "reply?▸ Run dotfiles install.sh as part of this run? [y/N] "
        [[ "${reply}" == [yY]* ]] && run_install=1
    fi

    # The zinit reset is a full wipe+reinstall (~400MB re-download), so it is opt-in the same
    # way — off unless you ask for it or pass --zinit.
    if (( ! run_zinit )) && [[ -t 0 ]]; then
        local zreply=""
        read -r "zreply?▸ Reset & update zinit plugins (full reinstall, ~400MB)? [y/N] "
        [[ "${zreply}" == [yY]* ]] && run_zinit=1
    fi

    local log_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/logs/maintain"
    mkdir -p "${log_dir}"
    local log_file="${log_dir}/maintain-$(date +%Y%m%d-%H%M%S).log"

    maintain::run 2>&1 | tee "${log_file}"
    local ret=${pipestatus[1]}

    # Retention: filenames sort chronologically; On = newest first; [11,-1] = older ones.
    local -a old_logs=( "${log_dir}"/maintain-*.log(On[11,-1]) )
    (( ${#old_logs} )) && rm -f "${old_logs[@]}"

    return ${ret}
}

# Phase-6 sub-section header: a blank line then a titled rule, so each audit reads as its own
# block instead of a flat bullet list. Fixed rule (not zsh `(l:)` padding) because that counts
# BYTES, and the multibyte ─ would be split into mojibake.
function maintain::hdr() {
    print -r -- ""
    print -r -- "  ── ${1} ────────────────────────────────"
}

function maintain::run() {
    # Keep option/trap changes local so we never leak state into the caller's shell.
    setopt local_options local_traps

    local start=${SECONDS}
    local -a failures
    local initial_df="$(command df -h / | awk 'NR==2 {print $4}')"

    print -r -- "=================================================="
    print -r -- "          🚀 Starting System Maintenance          "
    print -r -- "=================================================="

    # sudo shim: an EMPTY array when already root (servers/containers), so
    # "${sudo_cmd[@]}" <cmd> works everywhere without sprinkling EUID checks through the
    # phases — zsh expands a quoted empty array to zero words, not to an empty argument.
    local -a sudo_cmd
    (( EUID == 0 )) && sudo_cmd=() || sudo_cmd=(sudo)
    local can_sudo=$(( $+commands[sudo] || EUID == 0 ))
    local in_container="${IS_DEVCONTAINER:-false}"

    # Prime sudo up front so any password prompt lands now — not ten minutes into what
    # should be an unattended run — and refresh the timestamp in a background loop so no
    # single step stalls waiting for re-auth. macOS is primed too (softwareupdate needs
    # it). The loop self-exits if the parent shell dies; the trap tears it down on
    # normal return or Ctrl-C.
    local sudo_keepalive_pid=""
    if (( $+commands[sudo] && EUID != 0 )); then
        print -r -- $'\n▸ Priming sudo (keep-alive for unattended run)'
        if sudo -v 2>/dev/null; then
            while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 60; done &!
            sudo_keepalive_pid=${!}
            trap '[[ -n "${sudo_keepalive_pid}" ]] && kill "${sudo_keepalive_pid}" 2>/dev/null' EXIT INT TERM
        fi
    fi

    # Dotfiles bootstrap, opt-in via the wrapper's prompt (default N). Unnumbered, like
    # the sudo prime above, because it is not one of the six phases.
    #
    # Runs BEFORE the package phases on purpose: install.sh is idempotent and may install
    # new tools, and anything it adds then gets updated by phases 1-3 in the same pass.
    # It also inherits the sudo credential primed just above, so its privileged steps do
    # not re-prompt. Failure is recorded, never fatal — same contract as every other step.
    if (( run_install )); then
        maintain::hdr "Dotfiles bootstrap (install.sh)"
        print -r -- "    ${install_script}"
        "${install_script}" || failures+=("install.sh")
    fi

    # ----------------------------------------------------
    # 1. OS & SYSTEM PACKAGE MANAGERS
    # ----------------------------------------------------
    print -r -- $'\n▸ [1/6] System & OS Package Managers'

    if [[ "${in_container}" == "true" ]]; then
        # Homebrew is user-scoped and works fine in a container, so it still runs below;
        # what gets skipped is anything that touches the host OS (apt/flatpak/snap/fwupd).
        print -r -- "  (devcontainer detected — skipping host OS package steps)"
    fi

    # Homebrew covers macOS AND Linuxbrew (Linux/WSL) alike.
    if (( $+commands[brew] )); then
        maintain::hdr "Homebrew (update, upgrade, cleanup, autoremove)"
        { brew update && brew upgrade && brew cleanup -s && brew autoremove } || failures+=("Homebrew")
    fi

    if [[ "${HOST_OS}" == "darwin" ]]; then
        (( $+commands[mas] )) && { maintain::hdr "Mac App Store (mas)"; mas upgrade || failures+=("mas") }
        # macOS system updates (uses the sudo primed above). Deliberately -ir, not -ia:
        # -a installs EVERY available update including major OS upgrades, which can run
        # for half an hour and leave the machine demanding a reboot — not something an
        # unattended cache-pruning pass should decide on your behalf. -r restricts it to
        # Apple's recommended (security/point-release) set.
        (( can_sudo )) && { maintain::hdr "macOS system updates (softwareupdate, recommended only)"; "${sudo_cmd[@]}" softwareupdate -ir || failures+=("softwareupdate") }
    elif [[ "${in_container}" != "true" ]] && (( $+commands[apt-get] && can_sudo )); then
        maintain::hdr "Apt (update, upgrade, autoremove, clean)"
        # A debconf dialog here is unrecoverable, not merely awkward: maintain::run's
        # stdout is a PIPE (the tee wrapper), so whiptail's cursor-positioning escapes
        # interleave with the log stream and paint an unusable screen, while stdin is
        # still the tty — the run then blocks forever on a dialog you cannot steer.
        # `-y` only answers apt's OWN prompts; it does nothing for maintainer scripts.
        # needrestart's "Pending kernel upgrade" notice is the usual culprit.
        #
        # `env` (rather than exporting) because sudo's env_reset drops DEBIAN_FRONTEND;
        # it also works unchanged when sudo_cmd is empty on root shells.
        local -a apt_env=( env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a )
        # confold/confdef: never silently clobber a conffile you have edited. The cost is
        # reconciling the occasional .dpkg-dist by hand — preferable to an unattended
        # sweep rewriting configs. `dpkg --audit` and `phase 6`'s needrestart -r l report
        # still surface anything that needs a human.
        # Quoting is load-bearing: unquoted, zsh's EQUALS expansion fires on the `=--force-…`
        # tail and dies with "--force-confold not found".
        local -a apt_opts=( -o 'Dpkg::Options::=--force-confold' -o 'Dpkg::Options::=--force-confdef' )
        # `full-upgrade` (not plain `upgrade`): it performs the upgrade AND resolves
        # dependency/kernel-meta changes that `upgrade` refuses to touch — the case where
        # a new package must be installed or an obsolete one removed to complete the set
        # (e.g. a linux-image meta-package pulling a newer kernel). The tradeoff is that it
        # MAY remove packages to satisfy those dependencies, so it is less conservative
        # than `upgrade`; the resulting reboot-required flag is surfaced by phase 6's
        # server report, and the following `autoremove` sweeps the now-orphaned deps.
        # `clean`, not `autoclean`: autoclean only drops .debs that can no longer be
        # downloaded from any configured repo, so on a machine whose repos are all current
        # it deletes nothing — /var/cache/apt/archives had grown to 1020M across 632 files
        # (a 134M chrome, two docker-ce builds) while autoclean reported 0 removals every
        # run. Every cached .deb is re-downloadable on demand, so the only cost is
        # re-fetching a package you happen to reinstall soon after.
        # `autoremove --purge`: also drop the CONFIG files of the packages being auto-removed
        # — most importantly superseded kernels (old linux-image/-headers pile up in /boot
        # and can fill a small /boot partition), plus leftover /etc cruft. It only ever
        # touches packages apt already considers orphaned, so it is as safe as plain
        # autoremove, just more thorough.
        { "${sudo_cmd[@]}" "${apt_env[@]}" apt-get update \
            && "${sudo_cmd[@]}" "${apt_env[@]}" apt-get "${apt_opts[@]}" full-upgrade -y \
            && "${sudo_cmd[@]}" "${apt_env[@]}" apt-get autoremove --purge -y \
            && "${sudo_cmd[@]}" "${apt_env[@]}" apt-get clean } || failures+=("apt")
    elif [[ "${in_container}" != "true" ]] && (( $+commands[pacman] && can_sudo )); then
        # Arch / Manjaro / EndeavourOS — parity with install.sh, which does the initial
        # -Syu. Without this, pacman boxes only got upgrades on a full install.sh re-run.
        maintain::hdr "Pacman / AUR (full upgrade, cache, orphans)"
        # Arch has no partial upgrades: always sync-DB + upgrade in ONE transaction, never
        # `-Sy` then `-S` (that path bricks systems). Prefer an AUR helper so AUR packages
        # upgrade too — but ONLY as a non-root user: paru/yay refuse to run as root because
        # they invoke sudo themselves for the privileged steps.
        local pac_rc=0
        if (( EUID != 0 && $+commands[paru] )); then
            paru -Syu --noconfirm || pac_rc=1
        elif (( EUID != 0 && $+commands[yay] )); then
            yay -Syu --noconfirm || pac_rc=1
        else
            "${sudo_cmd[@]}" pacman -Syu --noconfirm || pac_rc=1
        fi
        # Trim the download cache to the currently-installed set (-Sc) and remove true
        # orphans (-Qtdq = deps nothing installed still needs). An empty orphan list makes
        # `-Rns -` exit non-zero, which is not a failure — hence the guard and `|| true`.
        "${sudo_cmd[@]}" pacman -Sc --noconfirm 2>/dev/null || true
        local pac_orphans; pac_orphans="$(pacman -Qtdq 2>/dev/null)"
        if [[ -n "${pac_orphans}" ]]; then
            print -r -- "${pac_orphans}" | "${sudo_cmd[@]}" pacman -Rns --noconfirm - 2>/dev/null || true
        fi
        (( pac_rc )) && failures+=("pacman")
    fi

    # Universal Linux distribution packages
    [[ "${in_container}" != "true" ]] && (( $+commands[flatpak] )) && { maintain::hdr "Flatpak packages"; { flatpak update -y && flatpak uninstall --unused -y } || failures+=("flatpak") }

    # Snap: snapd never runs under WSL (the command exists but every call fails) and it
    # requires systemd — check the socket is actually active before trying.
    if [[ "${in_container}" != "true" && "${HOST_OS}" != "wsl" ]] && (( $+commands[snap] && can_sudo )); then
        if (( $+commands[systemctl] )) && systemctl is-active -q snapd.socket 2>/dev/null; then
            maintain::hdr "Snap packages"
            "${sudo_cmd[@]}" snap refresh || failures+=("snap")
            # Reclaim space: snap keeps old revisions of every package forever by default
            # (each is a mounted squashfs — they add up fast). Cap retention at 2, then drop
            # the revisions already marked 'disabled' (superseded). LANG=C pins the column
            # layout awk parses; the remove loop is best-effort (|| true via 2>/dev/null).
            maintain::hdr "Snap cleanup (retain=2, remove old revisions)"
            "${sudo_cmd[@]}" snap set system refresh.retain=2 2>/dev/null || true
            LANG=C "${sudo_cmd[@]}" snap list --all 2>/dev/null \
                | awk '/disabled/{print $1, $3}' \
                | while read -r _sn _rev; do
                    "${sudo_cmd[@]}" snap remove "${_sn}" --revision="${_rev}" 2>/dev/null
                done
        fi
    fi

    # Firmware updates: real Linux desktops only (fwupd talks to UEFI — pointless on
    # WSL; servers are handled conservatively; containers excluded above).
    # Run it under the sudo primed above: unprivileged fwupdmgr goes through polkit,
    # which would pop an interactive auth prompt in the middle of an unattended run.
    if [[ "${in_container}" != "true" && "${HOST_OS}" == "linux" && "${HOST_LOCATION:-}" == "desktop" ]] \
       && (( $+commands[fwupdmgr] && can_sudo )); then
        maintain::hdr "Firmware updates (fwupd)"
        # fwupdmgr reserves exit code 2 for "nothing to do" — both `refresh` (metadata
        # still fresh) and `update` (no devices need updating) return it on a perfectly
        # healthy machine. Treating that as failure would book a phantom fwupd entry in
        # the summary on every run, so only >2 counts as a real error.
        local fwupd_rc=0
        "${sudo_cmd[@]}" fwupdmgr refresh --force; (( $? > 2 )) && fwupd_rc=1
        "${sudo_cmd[@]}" fwupdmgr update -y;       (( $? > 2 )) && fwupd_rc=1
        (( fwupd_rc )) && failures+=("fwupd")
    fi


    # ----------------------------------------------------
    # 2. RUNTIMES & TOOLCHAIN MANAGERS
    # ----------------------------------------------------
    print -r -- $'\n▸ [2/6] Runtimes & Version Managers'

    # gh runs BEFORE the zinit wipe: gh is zinit-managed at a VERSIONED path
    # (cli---cli/gh_<ver>_linux_amd64/bin/gh). The wipe+reinstall happens in a child
    # shell, so this shell's PATH entry and command hash still point at the old
    # version's directory — which no longer exists once the reinstall pulls a newer
    # gh. The $+commands guard then passes on the stale hash and execution dies with
    # "command not found". mise-managed tools hit the SAME trap a few lines below — see
    # the PATH re-float after `mise upgrade`.
    (( $+commands[gh] )) && { maintain::hdr "GitHub CLI extensions"; gh extension upgrade --all || failures+=("gh extensions") }

    # The zinit reset is a full wipe+reinstall (~400MB re-download), so it is opt-in: enabled
    # by --zinit or by answering y to the prompt in maintain(). Off by default (bare Enter,
    # cron, CI).
    if (( run_zinit )); then
        maintain::hdr "Resetting Zinit Plugins"
        "${ZDOTDIR}/functions/zinit-reset" --go || failures+=("zinit reset")
        # Drop stale command-hash entries pointing into the pre-wipe plugin dirs, so the
        # steps below this line resolve correctly. This only repairs THIS process — we run in
        # a subshell (see the pipe in maintain()), so the calling shell keeps its stale hash
        # regardless; that is what the closing `exec zsh` in the summary is for.
        rehash
    else
        maintain::hdr "Skipping Zinit reset (pass --zinit or answer y to enable)"
    fi

    # Self-update only when mise is a standalone install (under $HOME). Package-manager
    # installs (brew/apt) can't self-update and would record a spurious failure.
    if (( $+commands[mise] )); then
        maintain::hdr "Mise runtimes"
        mise upgrade || failures+=("mise")
        [[ "${commands[mise]}" == "${HOME}"/* ]] && { mise self-update --yes || failures+=("mise self-update") }

        # mise install dirs are VERSIONED wherever a backend has no `latest` symlink (the
        # asdf vim pin resolves to .../mise-vim/9.2.0926/bin). The upgrade above deletes the
        # old dir, leaving this shell's PATH entry and command hash pointing into it — the
        # same trap the gh comment above describes. That is what made `uv cache prune` below
        # die with "command not found" while its $+commands guard still passed on the stale
        # hash. Rebuild mise's PATH slice from `mise bin-paths` (truth after the upgrade),
        # drop the stale mise dirs, then rehash. `mise activate`'s precmd hook and the
        # preexec re-float in .zshrc both do this per prompt, but neither can help here: no
        # prompt is drawn between this line and the end of the run.
        local -a mise_bins=( ${(f)"$(mise bin-paths 2>/dev/null)"} )
        # Drop empty entries first: an empty PATH element means CWD, not "nothing".
        mise_bins=( ${(@)mise_bins:#} )
        (( ${#mise_bins} )) && path=( "${mise_bins[@]}" ${(@)path:#*/mise/installs/*} )
        rehash
    fi
    (( $+commands[asdf] ))   && { maintain::hdr "Asdf plugins";      asdf plugin update --all || failures+=("asdf") }
    (( $+commands[rustup] )) && { maintain::hdr "Rustup toolchains"; rustup update || failures+=("rustup") }
    # `yes |` pre-answers sdkman's interactive "Do you want to install?" prompt.
    (( $+commands[sdk] ))    && { maintain::hdr "SDKMAN!";           { sdk update && yes | sdk upgrade } || failures+=("sdkman") }

    # Vim-plug plugins: install.sh runs PlugInstall ONCE at bootstrap, so already-installed
    # plugins never move again without this. Guard on plug.vim existing, not just vim, so a
    # vim with no plugin manager is skipped rather than erroring on an unknown command.
    if (( $+commands[vim] )) && [[ -r "${HOME}/.vim/autoload/plug.vim" ]]; then
        maintain::hdr "Vim-plug plugins (upgrade plug.vim + update + clean plugins)"
        # Headless + synchronous: maintain::run's stdout is the tee PIPE, so vim's normal
        # full-screen PlugUpdate window would paint terminal escapes straight into the log.
        # -es (silent Ex) drops the UI; `PlugUpdate --sync` forces vim-plug's parallel
        # updater to run synchronously so `qall!` doesn't quit mid-download; </dev/null
        # keeps vim off the tty (it shares stdin with the terminal here); -i NONE skips
        # viminfo. PlugUpgrade self-updates plug.vim itself before the plugin pass, and
        # PlugClean! (banged = no prompt) removes plugin dirs no longer declared in .vimrc,
        # mirroring what the zinit reset does for shell plugins.
        vim -N -es -u "${HOME}/.vimrc" -i NONE \
            -c 'PlugUpgrade' -c 'PlugUpdate --sync' -c 'qall!' </dev/null \
            || failures+=("vim-plug")
        # PlugClean! gets its own vim and its status is deliberately NOT tracked. Under -es
        # it has no real window, so its range op raises "E16: Invalid range" and vim exits 1
        # even on the success path — it prints "Already clean." first, then fails. Chained
        # into the command above it set the exit code for the whole invocation, so every
        # maintain run booked vim-plug as broken while the update had actually worked.
        # The command is left UNGUARDED and the exit status absorbed by `|| true`. Both
        # obvious guards lose the output: `silent! PlugClean!` suppresses the messages, and
        # `try | PlugClean! | catch | endtry` aborts at the error before plug echoes its
        # result — measured, both write 0 bytes. Bare + `|| true` exits 0 AND keeps
        # "Already clean." / "Removed X" in the log, which is the whole point of running it.
        vim -N -es -u "${HOME}/.vimrc" -i NONE \
            -c 'PlugClean!' -c 'qall!' </dev/null || true
    fi

    # TPM (tmux plugin manager) — the tmux analog to the vim-plug step above. TPM lives at
    # $XDG_CONFIG_HOME/tmux/plugins/tpm (tmux.conf runs it from there), and install.sh never
    # updates it. update_plugins pulls new commits for every plugin; clean_plugins removes
    # plugin dirs no longer declared in tmux.conf. The bin/ scripts run standalone (no
    # attached session needed); </dev/null keeps them off the tty inside the tee pipe.
    local tpm_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/tmux/plugins/tpm"
    if (( $+commands[tmux] )) && [[ -x "${tpm_dir}/bin/update_plugins" ]]; then
        maintain::hdr "Tmux plugins (TPM update + clean)"
        { "${tpm_dir}/bin/update_plugins" all && "${tpm_dir}/bin/clean_plugins" } </dev/null || failures+=("tpm")
    fi

    # Claude Code self-updates in place. Guard to the standalone install under $HOME (the
    # native installer's ~/.local/bin): a system- or npm-managed copy can't self-update and
    # would only book a spurious failure — same contract as the mise/uv self-update guards.
    if (( $+commands[claude] )) && [[ "${commands[claude]}" == "${HOME}"/* ]]; then
        maintain::hdr "Claude Code"
        claude update </dev/null || failures+=("Claude Code")
    fi


    # ----------------------------------------------------
    # 3. GLOBAL PACKAGES & LANGUAGE CACHES
    # ----------------------------------------------------
    print -r -- $'\n▸ [3/6] Global Packages & Build Caches'

    # Node / JS ecosystem
    # The cache is cleared by path, not via `bun pm cache rm`: every `bun pm` subcommand
    # resolves a project root first and hard-fails ("No package.json was found", rc=1)
    # when run outside one — which is always, since `maintain` runs from wherever you
    # happen to be. The location is deterministic from BUN_INSTALL (set in .zshenv), and
    # BUN_INSTALL_CACHE_DIR overrides it when set, matching bun's own resolution order.
    if (( $+commands[bun] )); then
        maintain::hdr "Bun (upgrade & cache clear)"
        bun upgrade || failures+=("bun")
        rm -rf "${BUN_INSTALL_CACHE_DIR:-${BUN_INSTALL:-${HOME}/.bun}/install/cache}"
    fi
    (( $+commands[npm] )) && { maintain::hdr "NPM globals & cache"; { npm update -g && npm cache clean --force } || failures+=("npm") }

    # pnpm: bump globally-installed packages, and self-update ONLY the standalone install
    # (under PNPM_HOME, set in .zshenv) — a corepack/npm-managed pnpm can't self-update and
    # would just book a spurious failure, same reasoning as the mise/uv self-update guards.
    if (( $+commands[pnpm] )); then
        maintain::hdr "pnpm (self-update & global packages)"
        [[ -n "${PNPM_HOME}" && "${commands[pnpm]}" == "${PNPM_HOME}"/* ]] && { pnpm self-update </dev/null || failures+=("pnpm self-update") }
        pnpm update -g </dev/null || failures+=("pnpm globals")
    fi

    if (( $+commands[yarn] )) && [[ "$(yarn --version 2>/dev/null)" == 1.* ]]; then
        maintain::hdr "Yarn v1 globals & cache"
        { yarn global upgrade && yarn cache clean } || failures+=("yarn")
    fi

    # Python ecosystem. `uv self update` refuses (exit 2) on anything not installed by
    # the standalone script, and "lives under $HOME" is NOT sufficient to prove that: a
    # mise-managed uv sits at ~/.local/share/mise/installs/uv/…, passes the $HOME test,
    # and then fails on every single run. Exclude version-manager install trees, and let
    # the owning manager (mise upgrade, above) do the updating there.
    if (( $+commands[uv] )); then
        maintain::hdr "UV (self-update & cache prune)"
        if [[ "${commands[uv]}" == "${HOME}"/* && "${commands[uv]}" != *"/mise/installs/"* \
           && "${commands[uv]}" != *"/asdf/installs/"* ]]; then
            uv self update || failures+=("uv self-update")
        fi
        uv cache prune || failures+=("uv cache")
    fi
    (( $+commands[pipx] )) && { maintain::hdr "Pipx packages"; pipx upgrade-all || failures+=("pipx") }
    (( $+commands[pip] ))  && { maintain::hdr "Pruning Pip cache"; pip cache purge 2>/dev/null || true }

    # pynvim (vim/neovim Python provider): install.sh installs it but never bumps it. Upgrade
    # with the python's OWN pip, not `uv pip`: uv rejects `--user` outright ("pip's --user is
    # unsupported") and `uv pip` with no active venv errors too. The mise-managed python is
    # user-owned, so a plain `pip install --upgrade` writes to its site-packages with no
    # --user flag and no sudo. Guarded on pynvim already being importable, so we upgrade an
    # existing provider rather than installing one on a machine that never had it.
    if (( $+commands[mise] )) && mise exec -- python -c 'import pynvim' 2>/dev/null; then
        maintain::hdr "pynvim (vim python provider)"
        mise exec -- python -m pip install --upgrade pynvim </dev/null || failures+=("pynvim")
    fi

    # PHP ecosystem
    (( $+commands[composer] )) && { maintain::hdr "Composer globals"; composer global update || failures+=("composer") }

    # Compiled Languages (Go / Rust)
    (( $+commands[go] ))    && { maintain::hdr "Cleaning Go build cache"; go clean -cache -testcache || failures+=("go cache") }
    (( $+commands[cargo] )) && (( $+commands[cargo-cache] )) && { maintain::hdr "Cargo cache prune"; cargo cache --remove-dir git-db,registry-sources || failures+=("cargo cache") }
    # cargo-update refreshes cargo-installed binaries (dua-cli, qsv, yazi, …)
    (( $+commands[cargo-install-update] )) && { maintain::hdr "Cargo-installed binaries"; cargo install-update -a || failures+=("cargo install-update") }

    # Atuin history sync — the atuin BINARY already updates via the zinit reset (phase 2);
    # this pushes/pulls shell history against the sync server. Guard on the session file:
    # without a login `atuin sync` exits non-zero ("you are not logged in"), which would
    # book a spurious failure on every machine that doesn't use atuin's sync service.
    if (( $+commands[atuin] )) && [[ -f "${XDG_DATA_HOME:-${HOME}/.local/share}/atuin/session" ]]; then
        maintain::hdr "Atuin history sync"
        atuin sync </dev/null || failures+=("atuin sync")
    fi


    # ----------------------------------------------------
    # 4. DEVOPS & CONTAINER HYGIENE (SAFE MODES)
    # ----------------------------------------------------
    print -r -- $'\n▸ [4/6] Containers & Cloud Tools'

    # Safe Docker prune: keeps volumes intact, only removes items older than 7 days
    # (168h). If the user isn't in the docker group (common on servers), fall back to
    # sudo — the step used to be skipped silently in that case.
    local -a docker_cmd
    if (( $+commands[docker] )); then
        if docker info >/dev/null 2>&1; then
            docker_cmd=(docker)
        elif (( can_sudo )) && "${sudo_cmd[@]}" docker info >/dev/null 2>&1; then
            docker_cmd=("${sudo_cmd[@]}" docker)
        fi
    fi

    if (( ${#docker_cmd} )); then
        maintain::hdr "Docker prune (safe mode: keeping volumes, items <7 days old)"
        { "${docker_cmd[@]}" system prune -f --filter "until=168h" && "${docker_cmd[@]}" builder prune -f --filter "until=168h" } || failures+=("docker prune")
    elif (( $+commands[podman] )); then
        maintain::hdr "Podman system prune (safe mode)"
        podman system prune -f --filter "until=168h" || failures+=("podman prune")
    fi


    # ----------------------------------------------------
    # 5. SYSTEM CLEANUP & DOCUMENTATION REFRESH
    # ----------------------------------------------------
    print -r -- $'\n▸ [5/6] System Cleanup & Docs'

    (( $+commands[tldr] )) && { maintain::hdr "Updating tldr pages"; tldr --update || failures+=("tldr") }

    # mise never garbage-collects on its own: every `mise up` leaves the previous version
    # installed forever, so ~/.local/share/mise grows without bound (node/python runtimes
    # are 200-450MB each). prune keeps whatever is current per tracked config and drops the
    # superseded versions. It only removes versions no config still references, so it is
    # safe to run unattended — but note it will also drop tools you installed ad-hoc and
    # never pinned in mise/config.toml.
    (( $+commands[mise] )) && { maintain::hdr "mise (prune superseded tool versions)"; mise prune -y || failures+=("mise prune") }

    # Nix store garbage collection (only when nix is installed)
    (( $+commands[nix-collect-garbage] )) && { maintain::hdr "Nix store garbage collection"; nix-collect-garbage -d || failures+=("nix gc") }

    # Safely remove broken symlinks in local user bin directory
    if [[ -d "${HOME}/.local/bin" ]]; then
        maintain::hdr "Cleaning broken symlinks in ~/.local/bin"
        find -L "${HOME}/.local/bin" -maxdepth 1 -type l -exec rm -f {} + 2>/dev/null
    fi

    # Linux desktop only — HOST_OS 'linux' already excludes 'wsl' and 'darwin'. WSL has no
    # real disk to TRIM and no desktop trash to empty; macOS handles all of this itself.
    # Devcontainers skip all of it (ephemeral filesystem).
    if [[ "${HOST_OS}" == "linux" && "${in_container}" != "true" ]]; then
        if (( $+commands[fstrim] && can_sudo )); then
            maintain::hdr "SSD TRIM (fstrim -av)"
            "${sudo_cmd[@]}" fstrim -av || failures+=("fstrim")
        fi

        if (( $+commands[journalctl] && can_sudo )); then
            maintain::hdr "Vacuuming systemd journal (keep <2 weeks, cap 500M)"
            # Two bounds together: age (nothing older than 2 weeks) AND size (never more than
            # 500M total), so a burst of logging inside the window can't balloon /var/log.
            { "${sudo_cmd[@]}" journalctl --vacuum-time=2weeks \
                && "${sudo_cmd[@]}" journalctl --vacuum-size=500M } || failures+=("journal vacuum")
        fi

        # Crash-dump cleanup: systemd-coredump (/var/lib/systemd/coredump) and apport
        # (/var/crash) both accumulate large dumps that are almost never inspected after the
        # fact. Age-based (>14d) so a crash you're actively debugging this week survives.
        if (( can_sudo )); then
            if [[ -d /var/lib/systemd/coredump ]]; then
                maintain::hdr "Clearing old systemd coredumps (>14 days)"
                "${sudo_cmd[@]}" find /var/lib/systemd/coredump -type f -mtime +14 -delete 2>/dev/null
            fi
            if [[ -d /var/crash ]]; then
                maintain::hdr "Clearing old crash reports (/var/crash, >14 days)"
                "${sudo_cmd[@]}" find /var/crash -mindepth 1 -mtime +14 -delete 2>/dev/null
            fi
        fi

        # Age-based (30d) instead of wipe-all: recently trashed files survive a cleanup.
        maintain::hdr "Emptying user trash (deleted more than 30 days ago)"
        if (( $+commands[trash-empty] )); then
            trash-empty -f 30 2>/dev/null
        else
            # freedesktop.org trash spec. The age key is DeletionDate= inside each
            # info/<name>.trashinfo — NOT the mtime of the entry in files/. Trashing is a
            # rename(), which preserves the file's own mtime, so `find files/ -mtime +30`
            # would mean "last edited over 30 days ago": a document you wrote last year
            # and binned ten seconds ago would be destroyed on the very next run, while a
            # file edited yesterday but binned six months ago would live forever. The two
            # directories also have to be reaped in lockstep, or you strand .trashinfo
            # records whose payload is gone (and vice versa).
            #
            # DeletionDate is ISO-8601 with fixed-width fields, so a plain string
            # comparison against the cutoff orders it correctly.
            local trash_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/Trash"
            local cutoff="$(date -d '30 days ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null)"
            if [[ -n "${cutoff}" && -d "${trash_dir}/info" ]]; then
                local info_file deleted_at trashed_name
                for info_file in "${trash_dir}/info/"*.trashinfo(N); do
                    deleted_at="$(grep -m1 '^DeletionDate=' "${info_file}" 2>/dev/null)"
                    deleted_at="${deleted_at#DeletionDate=}"
                    # No parseable date → leave it alone rather than guess.
                    [[ -n "${deleted_at}" && "${deleted_at}" < "${cutoff}" ]] || continue
                    trashed_name="${${info_file:t}%.trashinfo}"
                    rm -rf "${trash_dir}/files/${trashed_name}" "${info_file}"
                done
            fi
        fi

        local thumb_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/thumbnails"
        if [[ -d "${thumb_dir}" ]]; then
            maintain::hdr "Clearing old thumbnails (>30 days)"
            find "${thumb_dir}" -type f -mtime +30 -delete 2>/dev/null
        fi
    fi

    # macOS developer caches — large and fully regenerable. Xcode rebuilds DerivedData on
    # demand; `simctl delete unavailable` drops simulators for SDKs you no longer have; old
    # iOS DeviceSupport (debug symbols for OS versions you haven't attached in months) is
    # dead weight. All macOS-only, user-scoped (no sudo).
    if [[ "${HOST_OS}" == "darwin" ]]; then
        local xc_dd="${HOME}/Library/Developer/Xcode/DerivedData"
        [[ -d "${xc_dd}" ]] && { maintain::hdr "Xcode DerivedData"; rm -rf "${xc_dd}"/*(N) 2>/dev/null }
        (( $+commands[xcrun] )) && { maintain::hdr "Removing unavailable simulators"; xcrun simctl delete unavailable 2>/dev/null }
        local ios_ds="${HOME}/Library/Developer/Xcode/iOS DeviceSupport"
        [[ -d "${ios_ds}" ]] && { maintain::hdr "Old iOS DeviceSupport (>90 days)"; find "${ios_ds}" -mindepth 1 -maxdepth 1 -mtime +90 -exec rm -rf {} + 2>/dev/null }
    fi

    # Cache-database refresh (desktop Linux): keep the font / desktop-entry / icon / man
    # databases consistent with what's installed. All cheap and non-fatal; user-scoped except
    # mandb (system, sudo). Skipped on servers/WSL/containers — no desktop DBs there.
    if [[ "${HOST_OS}" == "linux" && "${HOST_LOCATION:-}" == "desktop" && "${in_container}" != "true" ]]; then
        maintain::hdr "Refreshing font / desktop / icon / man databases"
        (( $+commands[fc-cache] )) && fc-cache -f 2>/dev/null
        (( $+commands[update-desktop-database] )) && update-desktop-database "${XDG_DATA_HOME:-${HOME}/.local/share}/applications" 2>/dev/null
        (( $+commands[gtk-update-icon-cache] )) && gtk-update-icon-cache -f -t "${XDG_DATA_HOME:-${HOME}/.local/share}/icons/hicolor" 2>/dev/null
        (( $+commands[mandb] && can_sudo )) && "${sudo_cmd[@]}" mandb -q 2>/dev/null
    fi

    # DNS cache flush — clears stale resolver entries. macOS uses the directory-service cache
    # + mDNSResponder; Linux uses systemd-resolved when it is the active resolver. WSL
    # resolves through the Windows host, so there's nothing local to flush.
    if [[ "${HOST_OS}" == "darwin" ]] && (( can_sudo )); then
        maintain::hdr "Flushing DNS cache"
        "${sudo_cmd[@]}" dscacheutil -flushcache 2>/dev/null
        "${sudo_cmd[@]}" killall -HUP mDNSResponder 2>/dev/null
    elif [[ "${HOST_OS}" == "linux" && "${in_container}" != "true" ]] && (( $+commands[resolvectl] && can_sudo )); then
        if (( $+commands[systemctl] )) && systemctl is-active -q systemd-resolved 2>/dev/null; then
            maintain::hdr "Flushing DNS cache (systemd-resolved)"
            "${sudo_cmd[@]}" resolvectl flush-caches 2>/dev/null || true
        fi
    fi

    # Zsh startup hygiene: precompile the whole config to .zwc, plus the completion dump (whose
    # .zwc zinit-reset already tries to clean but nothing currently creates). This intentionally
    # covers files the interactive `compile_if_needed` loop in .zshrc also touches, because that
    # loop cannot SEED a .zwc: zsh's `-nt` is false when the target is missing (unlike bash), so
    # `[[ src -nt src.zwc ]]` only ever refreshes an EXISTING .zwc, never creates the first one.
    # Here we compile when the .zwc is missing OR stale, so a full `maintain` run seeds them and
    # the interactive loop keeps them fresh thereafter. Then drop orphan .zwc whose source is gone.
    if (( $+commands[zsh] )) && [[ -n "${ZDOTDIR}" ]]; then
        maintain::hdr "Recompiling zsh files (.zwc)"
        local -aU zsrc=(
            "${ZDOTDIR}"/.zshenv "${ZDOTDIR}"/.zshrc "${ZDOTDIR}"/.zprofile
            "${ZDOTDIR}"/.zlogin "${ZDOTDIR}"/.zlogout "${ZDOTDIR}"/.p10k.zsh
            "${ZDOTDIR}"/*.zsh(N) "${ZDOTDIR}"/functions/*.zsh(N)
        )
        local zf
        for zf in "${zsrc[@]}"; do
            [[ -f "${zf}" ]] || continue
            [[ -f "${zf}.zwc" && ! "${zf}" -nt "${zf}.zwc" ]] && continue   # up to date → skip
            zcompile "${zf}" 2>/dev/null
        done
        local zdump="${XDG_CACHE_HOME:-${HOME}/.cache}/zsh/zcompdump"
        [[ -f "${zdump}" && ( ! -f "${zdump}.zwc" || "${zdump}" -nt "${zdump}.zwc" ) ]] && zcompile "${zdump}" 2>/dev/null
        for zf in "${ZDOTDIR}"/**/*.zwc(N); do [[ -f "${zf%.zwc}" ]] || rm -f "${zf}"; done
    fi


    # ----------------------------------------------------
    # 6. DIAGNOSTICS, INTEGRITY & SECURITY
    # ----------------------------------------------------
    print -r -- $'\n▸ [6/6] Health, Integrity & Security'

    maintain::hdr "Tool doctors"
    if [[ "${HOST_OS}" == "darwin" ]] && (( $+commands[brew] )); then
        brew doctor || print -r -- "    ⚠️ Homebrew doctor reported warnings."
    fi
    (( $+commands[mise] )) && { mise doctor || print -r -- "    ⚠️ mise doctor reported issues." }
    (( $+commands[brew] + $+commands[mise] == 0 )) && print -r -- "    (no brew/mise on this host)"

    # Informational only: never recorded as a failure, since a shadowed command is a thing
    # for a human to judge (some shadows are deliberate) rather than a broken step.
    maintain::hdr "PATH shadows"
    maintain::path_dupes

    # Permission audit — TIGHTEN ONLY (never loosens). Private key material and secret stores
    # must not be group/world-readable; chmod here only ever restricts to the standard modes,
    # so it is safe to run unattended.
    maintain::hdr "Permissions (SSH / GnuPG / secrets)"
    local -a perm_checked=()
    if [[ -d "${HOME}/.ssh" ]]; then
        chmod 700 "${HOME}/.ssh" 2>/dev/null
        chmod 600 "${HOME}"/.ssh/*(.N) 2>/dev/null       # every regular file → 600 first…
        chmod 644 "${HOME}"/.ssh/*.pub(.N) 2>/dev/null   # …then relax public keys back to 644
        perm_checked+=("~/.ssh")
    fi
    local gnupg_dir="${GNUPGHOME:-${XDG_CONFIG_HOME:-${HOME}/.config}/gnupg}"
    [[ -d "${gnupg_dir}" ]] && { chmod 700 "${gnupg_dir}" 2>/dev/null; perm_checked+=("${gnupg_dir/#${HOME}/~}") }
    [[ -d "${HOME}/.gnupg" ]] && { chmod 700 "${HOME}/.gnupg" 2>/dev/null; perm_checked+=("~/.gnupg") }
    local pass_dir="${PASSWORD_STORE_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/password-store}"
    [[ -d "${pass_dir}" ]] && { chmod 700 "${pass_dir}" 2>/dev/null; perm_checked+=("${pass_dir/#${HOME}/~}") }
    if (( ${#perm_checked} )); then
        print -r -- "    ✓ enforced strict perms on: ${(j:, :)perm_checked}"
    else
        print -r -- "    (no SSH / GnuPG / password-store dirs present)"
    fi

    # Broken-symlink audit (REPORT only — the ~/.local/bin auto-clean in phase 5 is the only
    # place we delete). Scans ~/.config (recursive), ~/.local/bin, and $HOME top-level.
    # ~/.local/share is deliberately excluded: mise/zinit trees carry intentional dangling
    # links and would drown the signal. `**` does not descend into symlinked dirs, so no loops.
    #
    # Many apps create symlinks that dangle BY DESIGN — chromium's Singleton{Lock,Cookie,Socket}
    # point at "host-pid", firefox locks at "ip:pid", and CLIs (codex, Claude) drop runtime
    # pointers under tmp/. Those aren't config breakage, so an ignore-list keeps the signal
    # clean (same idea as maintain::path_dupes' allowlist). Extend it as new noise shows up.
    maintain::hdr "Broken symlinks"
    # Precise, anchored patterns (not broad globs like */tmp/* which could swallow a real
    # broken link if any scanned path merely contained that segment).
    local -a link_ignore=(
        '*/Singleton*'            # chromium/chrome/brave/edge: lock links → host-pid, dangling by design
        '*/codex/tmp/*'           # codex CLI runtime temp pointers
        '*/claude/debug/*'        # Claude Code runtime debug pointer
        '*/lock' '*/.parentlock'  # firefox profile locks → ip:pid
    )
    local -a dangling=()
    local -i ignored=0
    local sl ig hit
    for sl in "${XDG_CONFIG_HOME:-${HOME}/.config}"/**/*(D@N) "${HOME}"/.local/bin/*(D@N) "${HOME}"/*(D@N); do
        [[ -e "${sl}" ]] && continue
        hit=0
        for ig in "${link_ignore[@]}"; do [[ "${sl}" == ${~ig} ]] && { hit=1; break } done
        (( hit )) && { (( ignored++ )); continue }
        dangling+=("${sl}")
    done
    print -r -- "    Scanned ~/.config, ~/.local/bin, ~/  (ignored ${ignored} known runtime/lock link(s))"
    if (( ${#dangling} )); then
        print -r -- "    ⚠️ ${#dangling} unexpected broken symlink(s):"
        print -rl -- ${${dangling[@]}/#${HOME}/~}
    else
        print -r -- "    ✓ no unexpected broken symlinks"
    fi

    # Dotfiles integrity (read-only). Repo root resolves through the ZDOTDIR symlink. Flag any
    # managed target that exists but is NOT a symlink back into the repo (drift — usually an
    # app rewrote a symlinked file), and warn on uncommitted/unpushed repo state. The list
    # mirrors a core subset of install.sh's SHARED_LINKS/ZSH_LINKS — keep in sync if it changes.
    local dotf="${ZDOTDIR:A:h}"
    maintain::hdr "Dotfiles integrity"
    if [[ -d "${dotf}/.git" ]]; then
        # Each entry must be a target install.sh actually links. NOTE: mise is linked at
        # FILE level (mise/config.toml → ~/.config/mise/config.toml); ~/.config/mise itself is
        # a real dir mise owns, so checking the dir would false-positive as "drift". The zsh /
        # atuin / tmux entries ARE whole-directory symlinks. Keep in sync with install.sh's
        # SHARED_LINKS / ZSH_LINKS.
        local cfg="${XDG_CONFIG_HOME:-${HOME}/.config}"
        local -a managed=(
            "${HOME}/.zshrc" "${HOME}/.zshenv" "${HOME}/.vimrc" "${HOME}/.vim"
            "${cfg}/zsh" "${cfg}/atuin" "${cfg}/mise/config.toml" "${cfg}/tmux"
        )
        local mt; local -i drift=0
        for mt in "${managed[@]}"; do
            [[ -e "${mt}" ]] || continue                 # absent → install.sh skips it too
            if [[ ! -L "${mt}" || "${mt:A}" != "${dotf}"/* ]]; then
                (( drift++ )); print -r -- "    ⚠️ drift: ${mt/#${HOME}/~} no longer links into the repo"
            fi
        done
        (( drift )) && print -r -- "    → run install.sh to repair managed symlinks"
        (( drift == 0 )) && print -r -- "    ✓ managed symlinks intact"
        if (( $+commands[git] )); then
            if [[ -n "$(git -C "${dotf}" status --porcelain 2>/dev/null)" ]]; then
                print -r -- "    ⚠️ ~/.dotfiles has uncommitted changes"
            else
                print -r -- "    ✓ ~/.dotfiles working tree clean"
            fi
            local unpushed="$(git -C "${dotf}" log --oneline @{u}.. 2>/dev/null | wc -l)"
            unpushed="${unpushed// /}"
            (( unpushed > 0 )) && print -r -- "    ⚠️ ~/.dotfiles has ${unpushed} unpushed commit(s)"
        fi
    else
        print -r -- "    (dotfiles git repo not found at ${dotf})"
    fi

    # Package & config health (read-only action items): pending config merges apt parks as
    # *.dpkg-dist under its confold/confdef policy (phase 1), half-configured packages
    # (dpkg --audit), and any still-pending security updates. Arch's equivalent is
    # *.pacnew/*.pacsave. After phase 1's full-upgrade the security count is usually 0.
    maintain::hdr "Package & config health"
    if [[ "${in_container}" != "true" ]] && (( $+commands[dpkg] )); then
        local -i pkg_issues=0
        local merges="$("${sudo_cmd[@]}" find /etc \( -name '*.dpkg-dist' -o -name '*.dpkg-new' -o -name '*.ucf-dist' \) 2>/dev/null)"
        if [[ -n "${merges}" ]]; then
            (( pkg_issues++ ))
            print -r -- "    ⚠️ pending config merges (review & merge):"
            print -r -- "${merges}" | while IFS= read -r sl; do print -r -- "        ${sl}"; done
        fi
        if (( can_sudo )); then
            local audit="$("${sudo_cmd[@]}" dpkg --audit 2>/dev/null)"
            [[ -n "${audit}" ]] && { (( pkg_issues++ )); print -r -- "    ⚠️ dpkg --audit reported broken package state (run: sudo dpkg --audit)" }
        fi
        local sec="$(LANG=C apt-get -s upgrade 2>/dev/null | grep -ciE '^Inst .*securi')"
        (( sec > 0 )) && { (( pkg_issues++ )); print -r -- "    ⚠️ ${sec} pending security update(s) — run apt full-upgrade" }
        [[ "${HOST_LOCATION:-}" == "server" ]] && (( ! $+commands[unattended-upgrade] )) && print -r -- "    ℹ️ unattended-upgrades not installed (recommended on servers)"
        (( pkg_issues == 0 )) && print -r -- "    ✓ no pending config merges, broken packages, or security updates"
    elif (( $+commands[pacman] )); then
        local -a pacnew=( /etc/**/*.pacnew(N) /etc/**/*.pacsave(N) )
        if (( ${#pacnew} )); then
            print -r -- "    ⚠️ pending pacman config merges:"; print -rl -- ${pacnew[@]/#/        }
        else
            print -r -- "    ✓ no .pacnew/.pacsave to merge"
        fi
    else
        print -r -- "    (no apt/pacman on this host)"
    fi

    # Read-only server status report — highlights action items, never changes state.
    if [[ "${HOST_LOCATION:-}" == "server" && "${HOST_OS}" == "linux" ]]; then
        maintain::hdr "Server status"
        local -i srv_clean=1

        if [[ -f /var/run/reboot-required ]]; then
            srv_clean=0
            print -r -- "    ⚠️ REBOOT REQUIRED"
            if [[ -f /var/run/reboot-required.pkgs ]]; then
                local pkgs="$(head -10 /var/run/reboot-required.pkgs | tr '\n' ' ')"
                print -r -- "      Packages: ${pkgs}"
            fi
        fi

        if [[ -d /run/systemd/system ]] && (( $+commands[systemctl] )); then
            local failed_units="$(systemctl list-units --failed --no-legend --plain 2>/dev/null)"
            if [[ -n "${failed_units}" ]]; then
                srv_clean=0
                local unit_line
                print -r -- "    ⚠️ Failed systemd units:"
                print -r -- "${failed_units}" | while IFS= read -r unit_line; do print -r -- "        ${unit_line}"; done
            fi
        fi

        if (( $+commands[journalctl] && can_sudo )); then
            local err_count="$("${sudo_cmd[@]}" journalctl -b -p err --no-pager -q 2>/dev/null | wc -l)"
            err_count="${err_count// /}"
            (( err_count > 0 )) && { srv_clean=0; print -r -- "    ⚠️ ${err_count} journal error(s) since boot — inspect: journalctl -b -p err" }
        fi

        (( srv_clean )) && print -r -- "    ✓ no reboot required, no failed units, no boot errors"
        (( $+commands[needrestart] && can_sudo )) && { print -r -- "    services needing restart (needrestart):"; "${sudo_cmd[@]}" needrestart -r l 2>/dev/null }
    fi

    # WSL runtime/kernel updates live on the WINDOWS side: `wsl --update` targets the WSL2
    # platform itself and cannot run from inside the distro (apt only updates the Ubuntu
    # userland). Surface it as a reminder — informational, never a recorded failure.
    if [[ "${HOST_OS}" == "wsl" ]]; then
        maintain::hdr "WSL runtime"
        print -r -- "    ℹ️ Run 'wsl --update' in Windows PowerShell to update the WSL kernel/runtime."
    fi

    # Disk-space report (read-only): show EVERY real filesystem with a ✓/⚠️ (≥90% = warn), then
    # list the biggest consumers under $HOME with the already-installed dust. Pseudo-filesystems
    # (tmpfs/overlay/squashfs) are excluded so containers, RAM disks, and snaps don't add noise.
    maintain::hdr "Disk usage"
    command df -hP 2>/dev/null | awk '
        NR>1 && $1 !~ /tmpfs|devtmpfs|overlay|udev|squashfs/ {
            flag = ($5+0 >= 90) ? "⚠️" : "✓"
            printf "    %s %-20s %4s used, %s free\n", flag, $6, $5, $4
        }'
    if (( $+commands[dust] )); then
        print -r -- "    Largest paths under ~:"
        dust -d 1 -n 12 "${HOME}" 2>/dev/null | while IFS= read -r sl; do print -r -- "      ${sl}"; done
    fi

    # Stop the sudo keep-alive before handing the terminal back (trap covers Ctrl-C).
    if [[ -n "${sudo_keepalive_pid}" ]]; then
        kill "${sudo_keepalive_pid}" 2>/dev/null
        sudo_keepalive_pid=""
    fi

    local final_df="$(command df -h / | awk 'NR==2 {print $4}')"
    local elapsed=$(( SECONDS - start ))

    print -r -- $'\n=================================================='
    print -r -- "✅ Maintenance Complete!"
    printf '   Elapsed:           %dm %02ds\n' $(( elapsed / 60 )) $(( elapsed % 60 ))
    print -r -- "   Storage Available: ${initial_df} ➔ ${final_df}"
    if (( ${#failures} )); then
        print -r -- "   ⚠️ ${#failures} step(s) failed:"
        local f
        for f in "${failures[@]}"; do print -r -- "        • ${f}"; done
    else
        print -r -- "   All steps completed successfully."
    fi
    print -r -- "   Log saved to:      ${log_file}"
    print -r -- "   Run 'exec zsh' to apply updated command paths."
    print -r -- "=================================================="

    return $(( ${#failures} > 0 ))
}

# Familiar name kept working; `maintain` is now the canonical entry point.
alias update-all="maintain"
