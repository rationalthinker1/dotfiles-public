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

# Full-spectrum system maintenance in one pass: update system packages, shell plugins,
# and language toolchains, then prune caches, clean up, and health-check.
# Supersedes the old `update-all` (kept as an alias below).
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
    print -r -- "Usage: maintain [-h|--help]"
    print -r -- ""
    print -r -- "Full-spectrum system maintenance, run in six phases:"
    print -r -- "  1. System & OS package managers (brew/apt, flatpak, snap, firmware/macOS updates)"
    print -r -- "  2. Runtimes & version managers (gh, zinit reset, mise, rustup, …)"
    print -r -- "  3. Global packages & language build caches (npm, bun, uv, pipx, composer, go, cargo)"
    print -r -- "  4. Container hygiene (docker/podman prune, safe mode)"
    print -r -- "  5. System cleanup & docs (tldr, TRIM, journal, nix gc, trash/thumbnails >30d)"
    print -r -- "  6. Health checks & audits (brew/mise doctor, PATH shadow scan, server report)"
    print -r -- ""
    print -r -- "Before the phases begin, asks whether to run the dotfiles install.sh"
    print -r -- "bootstrap first (default N — a bare Enter skips it). The prompt is"
    print -r -- "suppressed entirely when stdin is not a terminal, so scripted and cron"
    print -r -- "runs always skip it."
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

    local arg
    for arg in "$@"; do
        case "${arg}" in
            (-h|--help)
                maintain::usage
                return 0
                ;;
            (*)
                print -ru2 -- "maintain: unknown option '${arg}'"
                return 2
                ;;
        esac
    done

    # Optional bootstrap re-run, asked HERE rather than inside maintain::run: that
    # function's stdout is the tee pipe, and a prompt written into a pipe is exactly the
    # trap that made the apt/debconf dialog unsteerable. Up here stdout is still the
    # terminal, and asking before the long unattended phases start mirrors why sudo is
    # primed up front — every question lands now, not ten minutes in.
    #
    # ZDOTDIR is ~/.config/zsh, a symlink into the repo, so :A resolves it before :h
    # takes the parent — a bare ${ZDOTDIR:h} would look in ~/.config and miss.
    #
    # Default is N: a bare Enter, EOF, or a non-tty stdin (cron, CI, `maintain < /dev/null`)
    # all mean skip. run_install/install_script are locals here; zsh's dynamic scoping
    # lets maintain::run see them through the pipeline subshell, same as log_file.
    local install_script="${ZDOTDIR:A:h}/install.sh"
    local run_install=0
    if [[ -t 0 && -r "${install_script}" ]]; then
        local reply=""
        read -r "reply?▸ Run dotfiles install.sh as part of this run? [y/N] "
        [[ "${reply}" == [yY]* ]] && run_install=1
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
        print -r -- $'\n▸ Running dotfiles bootstrap (install.sh)'
        print -r -- "  • ${install_script}"
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
        print -r -- "  • Homebrew (update, upgrade, cleanup, autoremove)"
        { brew update && brew upgrade && brew cleanup -s && brew autoremove } || failures+=("Homebrew")
    fi

    if [[ "${HOST_OS}" == "darwin" ]]; then
        (( $+commands[mas] )) && { print -r -- "  • Mac App Store (mas)"; mas upgrade || failures+=("mas") }
        # macOS system updates (uses the sudo primed above). Deliberately -ir, not -ia:
        # -a installs EVERY available update including major OS upgrades, which can run
        # for half an hour and leave the machine demanding a reboot — not something an
        # unattended cache-pruning pass should decide on your behalf. -r restricts it to
        # Apple's recommended (security/point-release) set.
        (( can_sudo )) && { print -r -- "  • macOS system updates (softwareupdate, recommended only)"; "${sudo_cmd[@]}" softwareupdate -ir || failures+=("softwareupdate") }
    elif [[ "${in_container}" != "true" ]] && (( $+commands[apt-get] && can_sudo )); then
        print -r -- "  • Apt (update, upgrade, autoremove, clean)"
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
        # `clean`, not `autoclean`: autoclean only drops .debs that can no longer be
        # downloaded from any configured repo, so on a machine whose repos are all current
        # it deletes nothing — /var/cache/apt/archives had grown to 1020M across 632 files
        # (a 134M chrome, two docker-ce builds) while autoclean reported 0 removals every
        # run. Every cached .deb is re-downloadable on demand, so the only cost is
        # re-fetching a package you happen to reinstall soon after.
        { "${sudo_cmd[@]}" "${apt_env[@]}" apt-get update \
            && "${sudo_cmd[@]}" "${apt_env[@]}" apt-get "${apt_opts[@]}" upgrade -y \
            && "${sudo_cmd[@]}" "${apt_env[@]}" apt-get autoremove -y \
            && "${sudo_cmd[@]}" "${apt_env[@]}" apt-get clean } || failures+=("apt")
    fi

    # Universal Linux distribution packages
    [[ "${in_container}" != "true" ]] && (( $+commands[flatpak] )) && { print -r -- "  • Flatpak packages"; { flatpak update -y && flatpak uninstall --unused -y } || failures+=("flatpak") }

    # Snap: snapd never runs under WSL (the command exists but every call fails) and it
    # requires systemd — check the socket is actually active before trying.
    if [[ "${in_container}" != "true" && "${HOST_OS}" != "wsl" ]] && (( $+commands[snap] && can_sudo )); then
        if (( $+commands[systemctl] )) && systemctl is-active -q snapd.socket 2>/dev/null; then
            print -r -- "  • Snap packages"
            "${sudo_cmd[@]}" snap refresh || failures+=("snap")
        fi
    fi

    # Firmware updates: real Linux desktops only (fwupd talks to UEFI — pointless on
    # WSL; servers are handled conservatively; containers excluded above).
    # Run it under the sudo primed above: unprivileged fwupdmgr goes through polkit,
    # which would pop an interactive auth prompt in the middle of an unattended run.
    if [[ "${in_container}" != "true" && "${HOST_OS}" == "linux" && "${HOST_LOCATION:-}" == "desktop" ]] \
       && (( $+commands[fwupdmgr] && can_sudo )); then
        print -r -- "  • Firmware updates (fwupd)"
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
    # "command not found". Every other tool below lives at a stable path.
    (( $+commands[gh] )) && { print -r -- "  • GitHub CLI extensions"; gh extension upgrade --all || failures+=("gh extensions") }

    print -r -- "  • Resetting Zinit Plugins"
    "${ZDOTDIR}/functions/zinit-reset" --go || failures+=("zinit reset")
    # Drop stale command-hash entries pointing into the pre-wipe plugin dirs, so the
    # steps below this line resolve correctly. This only repairs THIS process — we run in
    # a subshell (see the pipe in maintain()), so the calling shell keeps its stale hash
    # regardless; that is what the closing `exec zsh` in the summary is for.
    rehash

    # Self-update only when mise is a standalone install (under $HOME). Package-manager
    # installs (brew/apt) can't self-update and would record a spurious failure.
    if (( $+commands[mise] )); then
        print -r -- "  • Mise runtimes"
        mise upgrade || failures+=("mise")
        [[ "${commands[mise]}" == "${HOME}"/* ]] && { mise self-update --yes || failures+=("mise self-update") }
    fi
    (( $+commands[asdf] ))   && { print -r -- "  • Asdf plugins";      asdf plugin update --all || failures+=("asdf") }
    (( $+commands[rustup] )) && { print -r -- "  • Rustup toolchains"; rustup update || failures+=("rustup") }
    # `yes |` pre-answers sdkman's interactive "Do you want to install?" prompt.
    (( $+commands[sdk] ))    && { print -r -- "  • SDKMAN!";           { sdk update && yes | sdk upgrade } || failures+=("sdkman") }


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
        print -r -- "  • Bun (upgrade & cache clear)"
        bun upgrade || failures+=("bun")
        rm -rf "${BUN_INSTALL_CACHE_DIR:-${BUN_INSTALL:-${HOME}/.bun}/install/cache}"
    fi
    (( $+commands[npm] )) && { print -r -- "  • NPM globals & cache"; { npm update -g && npm cache clean --force } || failures+=("npm") }

    if (( $+commands[yarn] )) && [[ "$(yarn --version 2>/dev/null)" == 1.* ]]; then
        print -r -- "  • Yarn v1 globals & cache"
        { yarn global upgrade && yarn cache clean } || failures+=("yarn")
    fi

    # Python ecosystem. `uv self update` refuses (exit 2) on anything not installed by
    # the standalone script, and "lives under $HOME" is NOT sufficient to prove that: a
    # mise-managed uv sits at ~/.local/share/mise/installs/uv/…, passes the $HOME test,
    # and then fails on every single run. Exclude version-manager install trees, and let
    # the owning manager (mise upgrade, above) do the updating there.
    if (( $+commands[uv] )); then
        print -r -- "  • UV (self-update & cache prune)"
        if [[ "${commands[uv]}" == "${HOME}"/* && "${commands[uv]}" != *"/mise/installs/"* \
           && "${commands[uv]}" != *"/asdf/installs/"* ]]; then
            uv self update || failures+=("uv self-update")
        fi
        uv cache prune || failures+=("uv cache")
    fi
    (( $+commands[pipx] )) && { print -r -- "  • Pipx packages"; pipx upgrade-all || failures+=("pipx") }
    (( $+commands[pip] ))  && { print -r -- "  • Pruning Pip cache"; pip cache purge 2>/dev/null || true }

    # PHP ecosystem
    (( $+commands[composer] )) && { print -r -- "  • Composer globals"; composer global update || failures+=("composer") }

    # Compiled Languages (Go / Rust)
    (( $+commands[go] ))    && { print -r -- "  • Cleaning Go build cache"; go clean -cache -testcache || failures+=("go cache") }
    (( $+commands[cargo] )) && (( $+commands[cargo-cache] )) && { print -r -- "  • Cargo cache prune"; cargo cache --remove-dir git-db,registry-sources || failures+=("cargo cache") }
    # cargo-update refreshes cargo-installed binaries (dua-cli, qsv, yazi, …)
    (( $+commands[cargo-install-update] )) && { print -r -- "  • Cargo-installed binaries"; cargo install-update -a || failures+=("cargo install-update") }


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
        print -r -- "  • Docker prune (safe mode: keeping volumes, items <7 days old)"
        { "${docker_cmd[@]}" system prune -f --filter "until=168h" && "${docker_cmd[@]}" builder prune -f --filter "until=168h" } || failures+=("docker prune")
    elif (( $+commands[podman] )); then
        print -r -- "  • Podman system prune (safe mode)"
        podman system prune -f --filter "until=168h" || failures+=("podman prune")
    fi


    # ----------------------------------------------------
    # 5. SYSTEM CLEANUP & DOCUMENTATION REFRESH
    # ----------------------------------------------------
    print -r -- $'\n▸ [5/6] System Cleanup & Docs'

    (( $+commands[tldr] )) && { print -r -- "  • Updating tldr pages"; tldr --update || failures+=("tldr") }

    # mise never garbage-collects on its own: every `mise up` leaves the previous version
    # installed forever, so ~/.local/share/mise grows without bound (node/python runtimes
    # are 200-450MB each). prune keeps whatever is current per tracked config and drops the
    # superseded versions. It only removes versions no config still references, so it is
    # safe to run unattended — but note it will also drop tools you installed ad-hoc and
    # never pinned in mise/config.toml.
    (( $+commands[mise] )) && { print -r -- "  • mise (prune superseded tool versions)"; mise prune -y || failures+=("mise prune") }

    # Nix store garbage collection (only when nix is installed)
    (( $+commands[nix-collect-garbage] )) && { print -r -- "  • Nix store garbage collection"; nix-collect-garbage -d || failures+=("nix gc") }

    # Safely remove broken symlinks in local user bin directory
    if [[ -d "${HOME}/.local/bin" ]]; then
        print -r -- "  • Cleaning broken symlinks in ~/.local/bin"
        find -L "${HOME}/.local/bin" -maxdepth 1 -type l -exec rm -f {} + 2>/dev/null
    fi

    # Linux desktop only — HOST_OS 'linux' already excludes 'wsl' and 'darwin'. WSL has no
    # real disk to TRIM and no desktop trash to empty; macOS handles all of this itself.
    # Devcontainers skip all of it (ephemeral filesystem).
    if [[ "${HOST_OS}" == "linux" && "${in_container}" != "true" ]]; then
        if (( $+commands[fstrim] && can_sudo )); then
            print -r -- "  • SSD TRIM (fstrim -av)"
            "${sudo_cmd[@]}" fstrim -av || failures+=("fstrim")
        fi

        if (( $+commands[journalctl] && can_sudo )); then
            print -r -- "  • Vacuuming systemd journal (keep <2 weeks)"
            "${sudo_cmd[@]}" journalctl --vacuum-time=2weeks || failures+=("journal vacuum")
        fi

        # Age-based (30d) instead of wipe-all: recently trashed files survive a cleanup.
        print -r -- "  • Emptying user trash (deleted more than 30 days ago)"
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
            print -r -- "  • Clearing old thumbnails (>30 days)"
            find "${thumb_dir}" -type f -mtime +30 -delete 2>/dev/null
        fi
    fi


    # ----------------------------------------------------
    # 6. DIAGNOSTICS & HEALTH CHECKS
    # ----------------------------------------------------
    print -r -- $'\n▸ [6/6] Health Checks & Audits'

    if [[ "${HOST_OS}" == "darwin" ]] && (( $+commands[brew] )); then
        brew doctor || print -r -- "  ⚠️ Homebrew doctor reported warnings."
    fi

    (( $+commands[mise] )) && { mise doctor || print -r -- "  ⚠️ Mise doctor reported issues." }

    # Informational only: never recorded as a failure, since a shadowed command is a thing
    # for a human to judge (some shadows are deliberate) rather than a broken step.
    print -r -- "  • Duplicate executables on PATH"
    maintain::path_dupes

    # Read-only server status report — highlights action items, never changes state.
    if [[ "${HOST_LOCATION:-}" == "server" && "${HOST_OS}" == "linux" ]]; then
        print -r -- "  • Server status report (read-only)"

        if [[ -f /var/run/reboot-required ]]; then
            print -r -- "    ⚠️ REBOOT REQUIRED"
            if [[ -f /var/run/reboot-required.pkgs ]]; then
                local pkgs="$(head -10 /var/run/reboot-required.pkgs | tr '\n' ' ')"
                print -r -- "      Packages: ${pkgs}"
            fi
        fi

        if [[ -d /run/systemd/system ]] && (( $+commands[systemctl] )); then
            local failed_units="$(systemctl list-units --failed --no-legend --plain 2>/dev/null)"
            if [[ -n "${failed_units}" ]]; then
                local unit_line
                print -r -- "    ⚠️ Failed systemd units:"
                print -r -- "${failed_units}" | while IFS= read -r unit_line; do print -r -- "        ${unit_line}"; done
            fi
        fi

        (( $+commands[needrestart] && can_sudo )) && "${sudo_cmd[@]}" needrestart -r l 2>/dev/null

        if (( $+commands[journalctl] && can_sudo )); then
            local err_count="$("${sudo_cmd[@]}" journalctl -b -p err --no-pager -q 2>/dev/null | wc -l)"
            err_count="${err_count// /}"
            (( err_count > 0 )) && print -r -- "    ⚠️ ${err_count} journal error(s) since boot — inspect: journalctl -b -p err"
        fi
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
