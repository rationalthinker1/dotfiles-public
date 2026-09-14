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
# The install.sh bootstrap and the ~400MB zinit WIPE are opt-in (prompted, or forced with
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
# One deletion looks wrong and is not: phase 3 removes $npm_cache/_npx, $npm_cache/.npm
# and ~/.npm by PATH, immediately after running `npm cache clean --force`. That is not
# redundancy — `npm cache clean` only ever empties _cacache inside the ONE directory
# `npm config get cache` names. _npx is its sibling and is never cleaned; $cache/.npm is a
# nested orphan from a run whose HOME resolved to the cache dir; ~/.npm is the pre-XDG
# location, dead since npm_config_cache moved and unreachable by any npm command since.
# Measured here: 7.5G across the three, against a 48K _cacache that the weekly run had
# been dutifully emptying for months. See the comment at the npm step for the guards.
#
# On WSL only, phase 4 also re-asserts that Docker cannot autostart — every container
# back to restart=no, docker.service/.socket/containerd.service disabled at boot. Both
# drift back on their own (tools rewrite restart policies; a docker-ce upgrade re-enables
# the units), and an idle stack resurrecting itself is what exhausted this VM's RAM+swap.
# See zsh/functions/dock.zsh for the manual lifecycle this pairs with.
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
#
# That fast path is safe ONLY while .zshrc's zinit declarations are unchanged since
# install: then the saved ices are correct by construction and bulk update, which never
# refreshes them, has nothing to get wrong. It genuinely updates (verified: a plugin
# faked back to an older release was detected and upgraded). The moment a declaration
# changes, that plugin needs a wipe — a targeted update merges ices and cannot remove the
# ones you deleted. See docs/ZINIT_UPDATE_MECHANICS.md for the measurements.

function maintain::usage() {
    print -r -- "Usage: maintain [-h|--help] [--install] [--zinit] [--windows] [--only N,…|--skip N,…]"
    print -r -- ""
    print -r -- "Full-spectrum system maintenance — update, clean, fix, and verify — in seven phases:"
    print -r -- "  1. System & OS package managers (brew/apt/pacman, flatpak, snap+cleanup, firmware/macOS updates)"
    print -r -- "  2. Runtimes & version managers (gh, zinit update + ice audit, vim-plug, tmux/TPM, Claude Code, mise, rustup, …)"
    print -r -- "  3. Global packages & language build caches (npm, pnpm, bun, uv, pipx, pynvim, composer, go, cargo, atuin sync)"
    print -r -- "  4. Container hygiene (docker/podman prune safe mode; WSL: re-pin containers to restart=no and disable docker units at boot)"
    print -r -- "  5. Cleanup & caches (TRIM, journal, coredumps, macOS/dev caches, DNS flush, zsh recompile, font/desktop DBs)"
    print -r -- "  6. Health, integrity & security (doctors, PATH shadows, XDG audit, broken-link & dotfiles audit, config-merge/security report, permission audit, pending reboot, disk report)"
    print -r -- "  7. Service audits — whatever this host actually runs (nginx, MariaDB, Redis, PHP-FPM, Supervisor, FreeSWITCH, PM2, Docker, mail, UFW, Fail2Ban, TLS, log growth, inodes). Skips what is absent."
    print -r -- ""
    print -r -- "Options:"
    print -r -- "  --install   Run the dotfiles install.sh bootstrap first (skips its prompt)."
    print -r -- "  --zinit     FULL zinit wipe + reinstall, ~400MB (skips its prompt). Not needed to"
    print -r -- "              update: every run updates plugins and reinstalls any that drifted from"
    print -r -- "              .zshrc. Use it after editing an ice VALUE in place, which the audit"
    print -r -- "              cannot see (it compares ice names, not values)."
    print -r -- "  --windows   On WSL only, run the deployed Windows maintain command after profile sync."
    print -r -- "              It suppresses the Windows bootstrap prompt and requests one UAC elevation."
    print -r -- "  --only N,…  Run ONLY these phases (1-7). 'maintain --only 6,7' is a read-only health"
    print -r -- "              report; --only 3 redoes the package/cache pass without a 30-minute rerun."
    print -r -- "  --skip N,…  Run every phase EXCEPT these. Mutually exclusive with --only."
    print -r -- ""
    print -r -- "Every network step runs under a timeout (60s for probes, 20-30m for real"
    print -r -- "downloads) and a step killed on its deadline is reported as such, so a stalled"
    print -r -- "mirror fails the step instead of hanging the run forever."
    print -r -- ""
    print -r -- "Two steps are opt-in. Before the phases begin, maintain asks whether to run the"
    print -r -- "dotfiles install.sh bootstrap and whether to do a FULL zinit wipe (both default N —"
    print -r -- "a bare Enter skips them). Each prompt is suppressed when its flag is passed, and"
    print -r -- "both are suppressed entirely when stdin is not a terminal, so scripted and cron"
    print -r -- "runs skip them unless --install / --zinit are given. Declining the zinit prompt"
    print -r -- "does NOT skip zinit: plugins are still updated and any that drifted from .zshrc"
    print -r -- "are still reinstalled — only the wholesale ~400MB re-download is skipped."
    print -r -- ""
    print -r -- "Primes sudo up front and keeps it alive so the run is unattended"
    print -r -- "(root shells run sudo-free). Devcontainers skip OS-level steps."
    print -r -- "Skips any tool that isn't installed; records (never aborts on) failures"
    print -r -- "and prints a summary of reclaimed disk plus any steps that failed."
    print -r -- "Every run is logged to \${XDG_STATE_HOME:-~/.local/state}/logs/maintain/ (10 kept)."
    print -r -- "The run itself executes in a subshell (it is piped to tee), so finish with"
    print -r -- "'exec zsh' to pick up updated command paths."
}

# Best-effort version string for one binary, for the shadow report below. Prints nothing
# and returns 1 when the tool has no --version (bd, up) or does not answer in time.
#
# WHY exec at all: the report's whole claim is "a newer copy may be masked", and paths alone
# cannot support it. A stale cargo eza 0.23.4 beat the zinit-managed 0.23.5 here for weeks
# while every run printed the pair and said nothing about which was older.
#
# </dev/null matters more than the timeout: a binary that reads stdin when handed an
# unrecognised flag otherwise hangs the whole maintenance run with no output. timeout is a
# second belt and is coreutils-only — macOS has none in the base system, so it is optional.
#
# The parse takes the FIRST dotted-numeric token, which survives the shapes actually seen:
# `v24.21.0`, `jq-1.8.1`, `pip 25.3 from …`, and qsv's 200-character feature banner. A bare
# year cannot match because a `.` is required.
function maintain::cmd_version() {
    emulate -L zsh
    # emulate -L zsh turns EXTENDED_GLOB off, and the parse below is built entirely from it
    # — (#b), ## and [^0-9]# are all inert without this and the match silently never fires.
    setopt local_options extended_glob
    local bin="${1}" out w
    local -a tmo=()
    (( $+commands[timeout] )) && tmo=( timeout 2 )
    out="$( ${tmo[@]} "${bin}" --version 2>&1 </dev/null )" || return 1
    for w in ${=out}; do
        [[ "${w}" == (#b)[^0-9]#([0-9]##(.[0-9]##)##)* ]] || continue
        print -r -- "${match[1]}"
        return 0
    done
    return 1
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

    # A mise shim is not a shadow — it is a trampoline INTO the install sitting beside it,
    # so the pair is one tool counted twice. That noise is structural, not per-command: on a
    # host with mise-managed python+node+yarn it buried 12 of 25 findings, which is the exact
    # failure the allowlist above exists to prevent. Filtered by SHAPE below rather than by
    # name, so a newly managed toolchain doesn't silently reintroduce it.
    local mise_data="${XDG_DATA_HOME:-${HOME}/.local/share}/mise"

    local d f c l real win ver note
    local -A vers
    # Real version comparison, not string order. Ships with zsh; autoload is a no-op if a
    # caller already did it.
    autoload -Uz is-at-least
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
        # Drop the shim only when its own install is ALSO on PATH — that is the redundant
        # pair. A shim with no install beside it is genuinely masking a system copy (mise's
        # node over apt's), which is a real finding and stays.
        (( ${locs[(I)${mise_data}/installs/*]} )) && locs=( ${locs:#${mise_data}/shims/*} )
        (( ${#locs} > 1 )) || continue
        # Compare RESOLVED targets: /bin is a symlink to /usr/bin on Ubuntu, so the very
        # same file would otherwise be reported as a duplicate of itself on every box.
        reals=( ${locs[@]:A} )
        (( ${#reals} > 1 )) || continue
        # One path per line, PATH order preserved. The single-line form ran past 200 columns
        # once mise entered the picture and wrapped into an unreadable block; the whole point
        # is to compare paths against each other, which needs them aligned. ${HOME} collapses
        # to ~ for the same reason — these are user-tree paths and the prefix is pure noise.
        # Probe each DISTINCT file once — /bin/x and /usr/bin/x are one binary, and paying
        # two execs plus two timeouts to print the same string twice is pure waste.
        vers=()
        for l in ${locs}; do
            real="${l:A}"
            [[ -n "${vers[${real}]+x}" ]] || vers[${real}]="$(maintain::cmd_version "${l}")"
        done
        win="${vers[${locs[1]:A}]}"
        hits+=( "      ${c}" )
        for l in ${locs}; do
            ver="${vers[${l:A}]}"
            note=""
            # The finding this check exists for: a copy LATER in PATH is newer than the one
            # that actually runs. is-at-least does a real version compare, so 0.23.10 does
            # not read as older than 0.23.4 the way a string compare would.
            if [[ -n "${ver}" && -n "${win}" && "${ver}" != "${win}" ]] && is-at-least "${win}" "${ver}"; then
                note="  ⚠️ newer than the copy that runs"
            fi
            hits+=( "        - ${l/#${HOME}/~}${ver:+  ${ver}}${note}" )
        done
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
    local run_windows=0
    # All six unless --only/--skip narrow it. maintain::run reads this through dynamic
    # scoping, same as log_file below.
    local -a maintain_phases=( 1 2 3 4 5 6 7 )
    local only_list="" skip_list=""
    # A while loop, not `for arg in "$@"`: --only and --skip take a value, which may arrive
    # either as the next word or glued on with '='. Both spellings are accepted because
    # both are what one actually types.
    while (( $# )); do
        case "${1}" in
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
            (--windows)
                run_windows=1
                ;;
            (--only)
                # Guard the shift: with --only as the last word there is no ${2}, and the
                # extra shift underflows with "shift count must be <= $#" before the empty
                # value is ever validated below.
                (( $# >= 2 )) || { print -ru2 -- "maintain: --only needs a phase list, e.g. --only 3,5"; return 2 }
                only_list="${2}"; shift
                ;;
            (--only=*)
                only_list="${1#*=}"
                ;;
            (--skip)
                (( $# >= 2 )) || { print -ru2 -- "maintain: --skip needs a phase list, e.g. --skip 1"; return 2 }
                skip_list="${2}"; shift
                ;;
            (--skip=*)
                skip_list="${1#*=}"
                ;;
            (*)
                print -ru2 -- "maintain: unknown option '${1}'"
                return 2
                ;;
        esac
        shift
    done

    # Refuse the combination rather than inventing a precedence. "--only 3 --skip 3" has no
    # defensible answer, and a run that silently did something other than what was asked is
    # the worst outcome for a command that installs and deletes things.
    if [[ -n "${only_list}" && -n "${skip_list}" ]]; then
        print -ru2 -- "maintain: --only and --skip are mutually exclusive"
        return 2
    fi

    if [[ -n "${only_list}${skip_list}" ]]; then
        # Concatenate into a plain variable first. ${(s:,:)${a}${b}} is not valid — a flag
        # applies to ONE nested expansion, not to two glued together, and zsh rejects the
        # whole thing as "bad substitution". Exactly one of the two is ever non-empty here
        # (the mutual-exclusion check above guarantees it), so this is just the chosen list.
        local phase_arg="${only_list}${skip_list}"
        local -a requested=( ${(s:,:)phase_arg} )
        requested=( ${requested//[[:space:]]/} )
        requested=( ${requested:#} )
        if (( ! ${#requested} )); then
            print -ru2 -- "maintain: --${only_list:+only}${skip_list:+skip} needs a phase list, e.g. --${only_list:+only}${skip_list:+skip} 3,5"
            return 2
        fi
        local ph
        for ph in "${requested[@]}"; do
            if [[ "${ph}" != <1-7> ]]; then
                print -ru2 -- "maintain: '${ph}' is not a phase number (1-7)"
                return 2
            fi
        done
        if [[ -n "${only_list}" ]]; then
            maintain_phases=( ${(on)requested} )
        else
            maintain_phases=( ${maintain_phases:|requested} )
        fi
        # Joined separately: a (j:…:) flag and a :- default cannot share one expansion
        # (zsh rejects it as "bad substitution"), and --skip 1,2,3,4,5,6 makes empty real.
        local phases_desc="${(j:, :)maintain_phases}"
        print -r -- "▸ Phases this run: ${phases_desc:-none}"
    fi

    # Two opt-in steps are asked HERE, not inside maintain::run: that function's stdout is the
    # tee pipe, and a prompt written into a pipe is exactly the trap that made the apt/debconf
    # dialog unsteerable. Up here stdout is still the terminal, and asking before the long
    # unattended phases start mirrors why sudo is primed up front — every question lands now,
    # not ten minutes in.
    #
    # ZDOTDIR is ~/.config/zsh, a symlink into the repo, so :A resolves it before the :h hops
    # take the parents — a bare ${ZDOTDIR:h} would look in ~/.config and miss. Two hops, not
    # one: the link source is <repo>/config/zsh, so :A:h lands on config/ and :A:h:h on the
    # repo root.
    #
    # Default for both prompts is N: a bare Enter, EOF, or a non-tty stdin (cron, CI,
    # `maintain < /dev/null`) all mean skip. The matching --install / --zinit flags force the
    # step on and suppress its prompt, so scripted runs stay fully unattended.
    local install_script="${ZDOTDIR:A:h:h}/install.sh"
    if (( ! run_install )) && [[ -t 0 && -r "${install_script}" ]]; then
        local reply=""
        read -r "reply?▸ Run dotfiles install.sh as part of this run? [y/N] "
        [[ "${reply}" == [yY]* ]] && run_install=1
    fi

    # State the zinit situation BEFORE asking about the wipe. The right answer depends
    # entirely on it — how many plugins drifted, and whether anything is flagged — and the
    # prompt used to arrive with none of that on screen, so the choice was a guess.
    #
    # Cheap enough to run here: zi-audit is read-only and touches only the filesystem (it
    # compares each plugin's ._zinit metadata against .zshrc), no network and no plugin
    # loading. --ids lists what a wipe would repair; the full pass supplies the verdict
    # line, which also counts findings a wipe canNOT fix, such as declaration bugs.
    if (( ! run_zinit )) && [[ -t 0 ]] && (( $+functions[zi_audit] )) && maintain::phase_enabled 2; then
        local -a pre_drift
        pre_drift=( ${(f)"$(zi_audit --ids 2>/dev/null)"} )
        pre_drift=( ${pre_drift:#} )

        local pre_verdict
        pre_verdict="$(zi_audit --quiet 2>/dev/null)"
        pre_verdict="${pre_verdict##*$'\n'}"
        [[ -n "${pre_verdict}" ]] && print -r -- "▸ zinit: ${pre_verdict}"

        if (( ${#pre_drift} )); then
            print -r -- "    ${#pre_drift} plugin(s) drifted from .zshrc — a normal run repairs these:"
            local zp
            for zp in "${pre_drift[@]}"; do print -r -- "      • ${zp}"; done
        else
            print -r -- "    no drift — every plugin matches its .zshrc declaration"
        fi
        print -r -- "    Say y only if you edited what is INSIDE an ice — atclone'old' → atclone'new'."
        print -r -- "    Adding or removing an ice shows up above; changing one's contents does not."
    fi

    # Only the FULL WIPE is opt-in. Answering N (or running non-interactively) still updates
    # the plugins and still repairs any that drifted from .zshrc — it just does so
    # incrementally instead of re-downloading ~400MB.
    #
    # The one case incremental repair cannot reach: editing what is INSIDE an ice while
    # leaving its name alone, say atclone'rm -f qsv[a-z]*' becoming atclone'_qsv_prune'.
    # zinit snapshots a plugin's ices into ._zinit/ at install time and replays THAT on
    # every update, and zi_audit::declared keys on the ice NAME only — `${w%%[\'\"]*}`
    # discards everything from the first quote on. Both sides still read "atclone", so
    # nothing detects the change and the old value keeps firing forever. Only a wipe
    # re-reads .zshrc and re-snapshots.
    if (( ! run_zinit )) && [[ -t 0 ]] && maintain::phase_enabled 2; then
        local zreply=""
        read -r "zreply?▸ FULL zinit wipe + reinstall (~400MB)? Plugins update either way. [y/N] "
        [[ "${zreply}" == [yY]* ]] && run_zinit=1
    fi

    local log_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/logs/maintain"
    mkdir -p "${log_dir}"
    local log_file="${log_dir}/maintain-$(date +%Y%m%d-%H%M%S).log"

    # Decide about colour HERE, where stdout is still the terminal. Inside the pipeline every
    # stage's stdout is a pipe, so a `-t 1` test down there is always false and would disable
    # colour on exactly the interactive runs it is meant for. maintain::colorize reads this
    # through the same dynamic scoping as log_file.
    local maintain_color=0
    [[ -t 1 ]] && maintain_color=1

    # Three stages, and the order is the point: tee writes the RAW stream to the log, then
    # only the copy heading for the terminal gets painted. Archived logs stay greppable
    # plain text. pipestatus[1] is still maintain::run — neither tee nor the filter can mask
    # its exit status.
    maintain::run 2>&1 | tee "${log_file}" | maintain::colorize
    local ret=${pipestatus[1]}

    # Retention: filenames sort chronologically; On = newest first; [11,-1] = older ones.
    local -a old_logs=( "${log_dir}"/maintain-*.log(On[11,-1]) )
    (( ${#old_logs} )) && rm -f "${old_logs[@]}"

    return ${ret}
}

# Run zi-audit, echo its output verbatim, and keep two things for the closing summary: the
# LAST line — "N plugin(s) checked — all clean" / "… — N finding(s)" — in `zi_report`, and
# the flagged plugin ids in `zi_flagged`. Captured rather than printed straight through
# because the summary needs them as values; zsh's dynamic scoping lets this write
# maintain::run's locals, same as maintain::run reads maintain()'s.
# An empty capture (zinit not loaded) leaves zi_report empty and the summary line is skipped.
function maintain::zi_audit() {
    local out=""
    # --online here, but NOT on the pre-flight pass above: this is the reported audit, and
    # ver-stale is the one finding that cannot be seen from the filesystem alone. It costs
    # one GitHub request per PINNED gh-r plugin — normally zero, since nothing here is
    # pinned unless an upstream release is temporarily broken.
    out="$(zi_audit --quiet --online)"
    local rc=${?}
    [[ -n "${out}" ]] && print -r -- "${out}"
    zi_report="${out##*$'\n'}"
    # Ids to name in the summary: zi-audit marks each flagged plugin with a leading ✗ and
    # indents its findings beneath, so the ✗ lines alone are the id list. The orphan block
    # is a ✗ HEADING, not an id — it collapses to the bare word, its members stay above.
    # Count can differ from the findings count in the verdict: one plugin may carry several.
    zi_flagged=( ${${${(M)${(f)out}:#✗ *}#✗ }/orphans*/orphans} )
    return ${rc}
}

# mise never garbage-collects on its own: every `mise up` leaves the previous version
# installed forever, so ~/.local/share/mise grows without bound (node/python runtimes are
# 200-450MB each). `mise prune` keeps whatever is current per tracked config and drops the
# superseded versions — including anything installed ad-hoc and never pinned in
# mise/config.toml, which is the whole problem here.
#
# WHY this is not just `mise prune -y`: qsv's qsvpy31N binary dynamically links a
# libpython3.N that the distro may not package at all (Ubuntu 26.04 ships only 3.14, qsv
# builds only 3.11-3.13), so _qsv_fetch_python in .zshrc installs one via mise. It is
# deliberately absent from mise/config.toml — pinning it would put a second python on every
# machine and move the shims — so prune sees an unreferenced version and reclaims it. And
# it cannot be repaired on the next pass: `zi update` runs in phase 2, this in phase 5, so
# atpull can never win that race.
#
# `mise prune` takes a TOOL, not a tool@version, so protecting one version would drag every
# other version of that tool to safety with it. Enumerate `mise ls --prunable` and uninstall
# exactly instead. Entries are matched on tool@version and also on tool@<version minus its
# patch>, so a hand-written `python@3.13` covers whichever 3.13.x mise resolved. Append to
# the array from local.zsh for anything else this machine keeps unpinned.
# -U so the derived qsv entry does not accumulate across repeated `maintain` runs.
typeset -gaU MAINTAIN_MISE_PRUNE_KEEP=(${MAINTAIN_MISE_PRUNE_KEEP[@]})

# Reads the protected version out of the qsvpy wrapper rather than hardcoding one, so this
# cannot go stale when qsv adds a qsvpy314. Nothing is protected unless the wrapper exists:
# a host whose apt libpython works leaves qsvpy a plain SYMLINK to the binary and needs no
# mise python at all, and one that never shipped a qsvpy has no file there either.
function maintain::mise_prune_keep_qsv() {
    local wrapper="${ZINIT[PLUGINS_DIR]:-${HOME}/.local/share/zinit/plugins}/dathere---qsv/qsvpy" home
    [[ -f "${wrapper}" && ! -L "${wrapper}" ]] || return 0
    # Held in a real array first: ${${(M)…}[1]} would subscript the JOINED string and hand
    # back its first character.
    local -a hits=(${(M)${(f)"$(<${wrapper})"}:#PYTHONHOME=*})
    (( ${#hits} )) || return 0
    home="${${hits[1]#*\'}%%\'*}"
    [[ "${home}" == */installs/python/* ]] && MAINTAIN_MISE_PRUNE_KEEP+=("python@${home:t}")
    return 0
}

function maintain::mise_prune() {
    local line tool ver id
    local -a prunable failed=()
    maintain::mise_prune_keep_qsv

    prunable=(${(f)"$(mise ls --prunable 2>/dev/null)"})
    for line in "${prunable[@]}"; do
        tool="${${(z)line}[1]}" ver="${${(z)line}[2]}"
        [[ -n "${tool}" && -n "${ver}" ]] || continue
        id="${tool}@${ver}"
        if (( ${MAINTAIN_MISE_PRUNE_KEEP[(Ie)${id}]} || ${MAINTAIN_MISE_PRUNE_KEEP[(Ie)${tool}@${ver%.*}]} )); then
            print -r -- "  keeping ${id} (MAINTAIN_MISE_PRUNE_KEEP)"
            continue
        fi
        mise uninstall "${id}" || failed+=("${id}")
    done
    (( ${#prunable} )) || print -r -- "  no superseded tool versions"
    # Version pruning is handled above; this is the other half of `mise prune` — tracked
    # config links pointing at configs that no longer exist.
    mise prune --configs -y || failed+=("configs")
    (( ${#failed} == 0 ))
}

# Paint the run's output for the terminal.
#
# WHY THIS IS A FILTER AND NOT ~50 COLOURED print STATEMENTS: the run is tee'd to a log
# file. Colour emitted at the call site lands in that file too, and every archived log turns
# into escape-sequence soup that `grep`, `less` without -R, and any later diff all choke on.
# The log is the artefact you read a week later when something broke; it must stay plain.
#
# So the pipeline splits first and paints second — `maintain::run | tee "${log}" | colorize`.
# tee writes the raw stream to disk, and only what continues to the terminal is styled. As a
# bonus every existing `print -r -- "    ✓ …"` keeps working untouched, so this adds no risk
# to the 50-odd sites that produce the output.
#
# Matching is on the markers the phases already emit (✓ ⚠️ ℹ️ ▸ ── •), which is why those
# were worth keeping consistent. The summary's bullets are ambiguous on their own — the same
# "• foo" is a failure under one heading and a health warning under another — so the parser
# holds a little state and recolours them from whichever heading it last saw.
function maintain::colorize() {
    emulate -L zsh
    # Pass straight through when colour is unwanted or meaningless: NO_COLOR (the informal
    # standard), a dumb terminal, or stdout that is not a terminal at all — a cron run, or
    # `maintain | less`. maintain() computes the tty test before the pipe, since by the time
    # this function runs its own stdout may be anything.
    if [[ -n "${NO_COLOR:-}" || "${TERM:-dumb}" == dumb || "${maintain_color:-0}" != 1 ]]; then
        command cat
        return
    fi

    command awk '
    BEGIN {
        R  = "\033[0m";   B  = "\033[1m";   D = "\033[2m"
        GR = "\033[32m";  YE = "\033[33m";  RD = "\033[31m"
        CY = "\033[36m";  MA = "\033[35m";  BL = "\033[34m"
        mode = ""
    }
    # Summary headings set how the bullets beneath them are read.
    /step\(s\) failed:/            { mode = "fail" }
    /health warning\(s\)/          { mode = "warn" }
    /Zinit plugins:/               { mode = "zi"   }

    # Rules and banners.
    /^[=━]{10,}$/                  { print D $0 R; next }
    /🚀/                           { print B MA $0 R; next }
    /^✅/                          { print B GR $0 R; next }

    # Phase banner: "▸ [3/7] Global Packages & Build Caches".
    /^▸ \[[0-9]+\/[0-9]+\]/        { print B CY $0 R; next }
    # Other ▸ lines are the pre-flight prompts and notices.
    /^▸ /                          { print CY $0 R; next }
    # Section rule: "  ── Homebrew (…) ──────".
    /^  ── /                       { print B BL $0 R; next }

    # Per-line status markers.
    /⚠️/                            { print YE $0 R; next }
    /ℹ️/                            { print CY $0 R; next }
    /✓/                            { print GR $0 R; next }
    /✗/                            { print RD $0 R; next }

    # Summary bullets, coloured by the heading above them.
    /^ *• / {
        if (mode == "fail")      { print RD $0 R; next }
        else if (mode == "warn") { print YE $0 R; next }
        else                     { print CY $0 R; next }
    }
    # Summary key/value rows — dim the label, leave the value legible.
    /^   [A-Z][a-z].*: / {
        i = index($0, ":")
        print D substr($0, 1, i) R substr($0, i + 1)
        next
    }
    { print }
    '
}

# Phase-6 sub-section header: a blank line then a titled rule, so each audit reads as its own
# block instead of a flat bullet list. Fixed rule (not zsh `(l:)` padding) because that counts
# BYTES, and the multibyte ─ would be split into mojibake.
function maintain::hdr() {
    print -r -- ""
    print -r -- "  ── ${1} ────────────────────────────────"
}

# Read-only health findings are deliberately separate from failed maintenance commands.
# A held package, expiring certificate, or failed unit needs attention, but does not mean
# that the updater itself failed. `health_warnings` is local to maintain::run and reached
# through zsh's dynamic scoping, just like failures and the zinit summary state.
function maintain::health_warn() {
    health_warnings+=( "${1}" )
    print -r -- "    ⚠️ ${1}"
}

# Run one maintenance command under a deadline and book its failure.
#
# WHY a deadline at all: `maintain` is an unattended weekly run, and until now nothing in
# it could time out. A registry that accepts the TCP connection and then stops sending —
# the normal shape of a rate-limited or half-dead mirror — leaves `zi update`, `brew
# update` or `cargo install-update -a` blocked on read() forever. The run never finishes
# and never reports, which is strictly worse than failing: a failure is in the summary.
#
# Tiers are chosen per call site, not guessed here. 60s is for a PROBE — a metadata fetch
# or a doctor, where anything slower is already broken. 20m is for real work that
# legitimately downloads hundreds of megabytes over a slow link.
#
# rc 124 is timeout(1)'s own "killed on deadline" code, and it is reported distinctly:
# "zi update (timed out after 20m)" says something different to the reader than
# "zi update", and the difference is what tells you to look at the network rather than
# at the tool. --kill-after follows SIGTERM with SIGKILL for anything that ignores the
# first signal. Where coreutils' timeout is absent (a stripped container), the command
# runs unwrapped rather than not at all.
#
# CONSTRAINT: timeout(1) execs a BINARY, so this wraps external commands only — never a
# zsh function (maintain::mise_prune, maintain::zi_audit) and never a `{ a && b }` block.
# A multi-command chain is therefore written as several maintain::step calls joined with
# `&&`, all sharing one label: the short-circuit guarantees only the FIRST failure books
# an entry, so the summary still shows "apt" once rather than once per sub-command.
# Functions stay unwrapped; they are filesystem work, and the network calls nested inside
# them (zi_audit --online) carry their own per-request timeouts.
function maintain::step() {
    local label="${1}" limit="${2}"
    shift 2

    if (( $+commands[timeout] )); then
        timeout --kill-after=30s "${limit}" "$@"
    else
        "$@"
    fi
    local rc=${?}

    if (( rc == 124 )); then
        failures+=( "${label} (timed out after ${limit})" )
    elif (( rc != 0 )); then
        failures+=( "${label}" )
    fi
    return ${rc}
}

# Phase gate for --only / --skip. `maintain_phases` is set by the argument parser in
# maintain() and reached here through the same dynamic scoping as run_install and
# log_file; when neither flag was passed it holds all six, so the default path is
# unchanged and this is a constant-time array lookup per phase.
function maintain::phase_enabled() {
    (( ${maintain_phases[(Ie)${1}]} ))
}

function maintain::run() {
    # Keep option/trap changes local so we never leak state into the caller's shell.
    setopt local_options local_traps

    local start=${SECONDS}
    local -a failures
    local -a health_warnings
    # zi-audit's one-line verdict plus the plugins it flagged, surfaced in the closing
    # summary. zi_report stays empty when the zinit step is skipped (no zinit in this
    # shell), which drops the summary line; zi_flagged is empty on a clean audit.
    local zi_report=""
    local -a zi_flagged
    local initial_df="$(command df -h / | awk 'NR==2 {print $4}')"

    print -r -- "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print -r -- "          🚀 Starting System Maintenance          "
    print -r -- "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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
    if maintain::phase_enabled 1; then
    print -r -- $'\n▸ [1/7] 📦 System & OS Package Managers'

    if [[ "${in_container}" == "true" ]]; then
        # Homebrew is user-scoped and works fine in a container, so it still runs below;
        # what gets skipped is anything that touches the host OS (apt/flatpak/snap/fwupd).
        print -r -- "  (devcontainer detected — skipping host OS package steps)"
    fi

    # Homebrew covers macOS AND Linuxbrew (Linux/WSL) alike.
    if (( $+commands[brew] )); then
        maintain::hdr "Homebrew (update, upgrade, cleanup, autoremove)"
        maintain::step "Homebrew" 20m brew update \
            && maintain::step "Homebrew" 20m brew upgrade \
            && maintain::step "Homebrew" 10m brew cleanup -s \
            && maintain::step "Homebrew" 10m brew autoremove
    fi

    if [[ "${HOST_OS}" == "darwin" ]]; then
        (( $+commands[mas] )) && { maintain::hdr "Mac App Store (mas)"; maintain::step "mas" 20m mas upgrade }
        # macOS system updates (uses the sudo primed above). Deliberately -ir, not -ia:
        # -a installs EVERY available update including major OS upgrades, which can run
        # for half an hour and leave the machine demanding a reboot — not something an
        # unattended cache-pruning pass should decide on your behalf. -r restricts it to
        # Apple's recommended (security/point-release) set.
        (( can_sudo )) && { maintain::hdr "macOS system updates (softwareupdate, recommended only)"; maintain::step "softwareupdate" 30m "${sudo_cmd[@]}" softwareupdate -ir }
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
        maintain::step "apt" 10m "${sudo_cmd[@]}" "${apt_env[@]}" apt-get update \
            && maintain::step "apt" 30m "${sudo_cmd[@]}" "${apt_env[@]}" apt-get "${apt_opts[@]}" full-upgrade -y \
            && maintain::step "apt" 10m "${sudo_cmd[@]}" "${apt_env[@]}" apt-get autoremove --purge -y \
            && maintain::step "apt" 5m "${sudo_cmd[@]}" "${apt_env[@]}" apt-get clean
    elif [[ "${in_container}" != "true" ]] && (( $+commands[pacman] && can_sudo )); then
        # Arch / Manjaro / EndeavourOS — parity with install.sh, which does the initial
        # -Syu. Without this, pacman boxes only got upgrades on a full install.sh re-run.
        maintain::hdr "Pacman / AUR (full upgrade, cache, orphans)"
        # Arch has no partial upgrades: always sync-DB + upgrade in ONE transaction, never
        # `-Sy` then `-S` (that path bricks systems). Prefer an AUR helper so AUR packages
        # upgrade too — but ONLY as a non-root user: paru/yay refuse to run as root because
        # they invoke sudo themselves for the privileged steps.
        if (( EUID != 0 && $+commands[paru] )); then
            maintain::step "pacman" 30m paru -Syu --noconfirm
        elif (( EUID != 0 && $+commands[yay] )); then
            maintain::step "pacman" 30m yay -Syu --noconfirm
        else
            maintain::step "pacman" 30m "${sudo_cmd[@]}" pacman -Syu --noconfirm
        fi
        # Trim the download cache to the currently-installed set (-Sc) and remove true
        # orphans (-Qtdq = deps nothing installed still needs). An empty orphan list makes
        # `-Rns -` exit non-zero, which is not a failure — hence the guard and `|| true`.
        "${sudo_cmd[@]}" pacman -Sc --noconfirm 2>/dev/null || true
        local pac_orphans; pac_orphans="$(pacman -Qtdq 2>/dev/null)"
        if [[ -n "${pac_orphans}" ]]; then
            print -r -- "${pac_orphans}" | "${sudo_cmd[@]}" pacman -Rns --noconfirm - 2>/dev/null || true
        fi
    fi

    # Universal Linux distribution packages
    [[ "${in_container}" != "true" ]] && (( $+commands[flatpak] )) && { maintain::hdr "Flatpak packages"; maintain::step "flatpak" 30m flatpak update -y && maintain::step "flatpak" 10m flatpak uninstall --unused -y }

    # Snap: snapd never runs under WSL (the command exists but every call fails) and it
    # requires systemd — check the socket is actually active before trying.
    if [[ "${in_container}" != "true" && "${HOST_OS}" != "wsl" ]] && (( $+commands[snap] && can_sudo )); then
        if (( $+commands[systemctl] )) && systemctl is-active -q snapd.socket 2>/dev/null; then
            maintain::hdr "Snap packages"
            maintain::step "snap" 30m "${sudo_cmd[@]}" snap refresh
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
        #
        # Deliberately NOT maintain::step: that helper books any non-zero rc as a failure,
        # which would fire on the rc 2 this step treats as success. Wrapped in a bare
        # timeout instead, with 124 folded into the same >2 test — a firmware fetch that
        # hangs is a failure by either reading.
        local fwupd_rc=0
        local -a fwupd_to=()
        (( $+commands[timeout] )) && fwupd_to=( timeout --kill-after=30s 20m )
        "${fwupd_to[@]}" "${sudo_cmd[@]}" fwupdmgr refresh --force; (( $? > 2 )) && fwupd_rc=1
        "${fwupd_to[@]}" "${sudo_cmd[@]}" fwupdmgr update -y;       (( $? > 2 )) && fwupd_rc=1
        (( fwupd_rc )) && failures+=("fwupd")
    fi
    fi  # phase 1


    # ----------------------------------------------------
    # 2. RUNTIMES & TOOLCHAIN MANAGERS
    # ----------------------------------------------------
    if maintain::phase_enabled 2; then
    print -r -- $'\n▸ [2/7] 🧰 Runtimes & Version Managers'

    # gh runs BEFORE the zinit wipe: gh is zinit-managed at a VERSIONED path
    # (cli---cli/gh_<ver>_linux_amd64/bin/gh). The wipe+reinstall happens in a child
    # shell, so this shell's PATH entry and command hash still point at the old
    # version's directory — which no longer exists once the reinstall pulls a newer
    # gh. The $+commands guard then passes on the stale hash and execution dies with
    # "command not found". mise-managed tools hit the SAME trap a few lines below — see
    # the PATH re-float after `mise upgrade`.
    (( $+commands[gh] )) && { maintain::hdr "GitHub CLI extensions"; maintain::step "gh extensions" 5m gh extension upgrade --all }

    # The zinit reset is a full wipe+reinstall (~400MB re-download), so it is opt-in: enabled
    # by --zinit or by answering y to the prompt in maintain(). Off by default (bare Enter,
    # cron, CI).
    # Zinit plugins. The default path UPDATES them; --zinit is the full-wipe hammer.
    #
    # This used to be all-or-nothing — and the "nothing" was the default, so an ordinary
    # run never touched the plugins at all and the only way to update was to accept a
    # ~400MB wipe. The three steps below give the normal path teeth:
    #
    #   1. `zi update --all --parallel` is correct AND fast for every plugin whose .zshrc
    #      declaration is unchanged since install: its saved ices then match the config by
    #      construction, so bulk update's inability to refresh ices has nothing to get
    #      wrong. (It does genuinely update — verified against a plugin faked back a
    #      release.) --no-pager is mandatory: zi update pages by default and will block
    #      forever on a pipe with no tty.
    #   2. `zi-audit --ids` names the plugins whose on-disk metadata no longer matches
    #      .zshrc — the only ones that need more than an update.
    #   3. Those get wiped and reinstalled. A wipe is the ONLY complete repair: a targeted
    #      update merges ices and can never remove one you deleted from the declaration.
    #
    # Blind spot worth knowing: zi-audit compares ice NAMES, not values, because declared
    # values contain unevaluated command substitution (bpick"$(gh_asset …)"). Adding or
    # removing an ice is caught here; editing one IN PLACE is not — for that, run --zinit.
    # See docs/ZINIT_UPDATE_MECHANICS.md.
    # Zinit ITSELF, before its plugins. install.sh clones zinit.git once at bootstrap and
    # nothing ever moved it again — and `zinit-reset` deliberately preserves that checkout
    # while wiping everything else, so even the full-wipe path left the manager pinned at
    # whatever version the machine was built with. `zi update --all` updates the PLUGINS,
    # never the updater. Not maintain::step: `zi` is a shell function, and timeout(1) execs
    # a binary (see the helper's CONSTRAINT note).
    if (( $+functions[zi] )); then
        maintain::hdr "Zinit self-update"
        zi self-update </dev/null || failures+=("zi self-update")
    fi

    if (( run_zinit )); then
        maintain::hdr "Resetting Zinit Plugins (full wipe, ~400MB)"
        "${ZDOTDIR}/functions/zinit-reset" --go || failures+=("zinit reset")
        # Drop stale command-hash entries pointing into the pre-wipe plugin dirs, so the
        # steps below this line resolve correctly. This only repairs THIS process — we run in
        # a subshell (see the pipe in maintain()), so the calling shell keeps its stale hash
        # regardless; that is what the closing `exec zsh` in the summary is for.
        rehash
        (( $+functions[zi_audit] )) && { maintain::hdr "Verifying zinit ices"; maintain::zi_audit || failures+=("zinit audit") }
    elif (( $+functions[zi] )); then
        maintain::hdr "Updating zinit plugins"
        PAGER=cat GIT_PAGER=cat zi update --all --parallel --no-pager </dev/null \
            || failures+=("zi update")

        if (( $+functions[zi_audit] )); then
            maintain::hdr "Auditing zinit ices against .zshrc"
            local -a zi_drifted
            zi_drifted=( ${(f)"$(zi_audit --ids 2>/dev/null)"} )
            zi_drifted=( ${zi_drifted:#} )

            if (( ${#zi_drifted} )); then
                print -r -- "  ${#zi_drifted} plugin(s) drifted from .zshrc — reinstalling:"
                local zp zdir
                for zp in "${zi_drifted[@]}"; do
                    zdir="${ZINIT[PLUGINS_DIR]}/${zp//\//---}"
                    # Only ever delete a real directory strictly beneath PLUGINS_DIR.
                    [[ -n "${zp}" && -d "${zdir}" && "${zdir}" == "${ZINIT[PLUGINS_DIR]}"/?* ]] || continue
                    print -r -- "    ${zp}"
                    rm -rf -- "${zdir}"
                done
                # Turbo (wait'…') never fires in a script, so the reinstall needs a fresh
                # shell plus a scheduler burst — the same primitive zinit-reset uses.
                zsh -ic '@zinit-scheduler burst' >/dev/null 2>&1
                rehash
                maintain::zi_audit || failures+=("zinit drift unresolved")
            else
                print -r -- "  no drift — every plugin matches its .zshrc declaration"
                # --ids above only lists WIPE-REPAIRABLE drift; a full pass also reports the
                # findings it suppresses (unknown-ice, pick-no-match, orphans) and is the only
                # thing that produces the summary verdict. Filesystem reads only, so it is cheap.
                maintain::zi_audit || failures+=("zinit audit")
            fi
        fi
    else
        maintain::hdr "Skipping zinit (not loaded in this shell)"
    fi

    # Self-update only when mise is a standalone install (under $HOME). Package-manager
    # installs (brew/apt) can't self-update and would record a spurious failure.
    if (( $+commands[mise] )); then
        maintain::hdr "Mise runtimes"
        maintain::step "mise" 30m mise upgrade
        [[ "${commands[mise]}" == "${HOME}"/* ]] && maintain::step "mise self-update" 10m mise self-update --yes

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
    (( $+commands[asdf] ))   && { maintain::hdr "Asdf plugins";      maintain::step "asdf" 20m asdf plugin update --all }
    (( $+commands[rustup] )) && { maintain::hdr "Rustup toolchains"; maintain::step "rustup" 30m rustup update }
    # `yes |` pre-answers sdkman's interactive "Do you want to install?" prompt. `sdk` is a
    # shell function, so this one stays unwrapped (see maintain::step's CONSTRAINT note).
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
        maintain::step "vim-plug" 20m vim -N -es -u "${HOME}/.vimrc" -i NONE \
            -c 'PlugUpgrade' -c 'PlugUpdate --sync' -c 'qall!' </dev/null
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

        # coc.nvim's EXTENSIONS are a separate package tree under ~/.config/coc/extensions,
        # installed by coc itself and untouched by PlugUpdate — which only moves the coc.nvim
        # repo. Without this they stay at whatever version was first resolved. CocUpdateSync
        # is the blocking form; the async :CocUpdate would return before anything downloaded
        # and `qall!` would kill it mid-flight. Guarded on the plugin directory rather than
        # on exists(':CocUpdateSync'): the command is defined by coc's autoload, which has
        # not run yet at this point — the same trap documented for after/plugin guards in
        # the repo CLAUDE.md.
        if [[ -d "${HOME}/.vim/plugged/coc.nvim" ]]; then
            maintain::hdr "coc.nvim extensions"
            maintain::step "coc extensions" 20m vim -N -es -u "${HOME}/.vimrc" -i NONE \
                -c 'CocUpdateSync' -c 'qall!' </dev/null
        fi
    fi

    # Neovim 0.12 uses its built-in vim.pack rather than vim-plug. Unlike the
    # interactive command, force=true makes the weekly headless run apply every resolved
    # update without opening a review buffer. vim.pack persists the resolved revisions in
    # nvim-pack-lock.json, deliberately tracked with this config, so a changed lockfile is
    # the expected record of plugin updates to review and commit.
    if (( $+commands[nvim] )) && [[ -r "${XDG_CONFIG_HOME:-${HOME}/.config}/nvim/init.lua" ]]; then
        maintain::hdr "Neovim plugins (vim.pack update)"
        maintain::step "Neovim plugins" 20m nvim --headless -i NONE \
            -c 'lua if not vim.pack then error("vim.pack requires Neovim 0.12+") end; vim.pack.update(nil, { force = true })' \
            -c 'qall!' </dev/null

        # Mason's LSP servers/DAP adapters and nvim-treesitter's compiled parsers are both
        # installed OUTSIDE the plugin tree (~/.local/share/nvim/mason and .../parser), so
        # vim.pack.update moves neither. They are the only Neovim components with no update
        # path at all.
        #
        # Each is gated on its command actually existing at runtime rather than on the plugin
        # being declared, because either can be absent on a machine whose nvim config has
        # drifted — and an unknown command aborts the whole headless invocation. Run in one
        # nvim rather than two: both are async, and `sleep` inside the lua keeps the process
        # alive long enough for them to land before qall!.
        local -a nvim_post=()
        nvim_post+=( -c 'lua if vim.fn.exists(":MasonUpdate") == 2 then vim.cmd("MasonUpdate") end' )
        nvim_post+=( -c 'lua if vim.fn.exists(":TSUpdateSync") == 2 then vim.cmd("TSUpdateSync") elseif vim.fn.exists(":TSUpdate") == 2 then vim.cmd("TSUpdate") end' )
        maintain::hdr "Neovim LSP servers & treesitter parsers"
        maintain::step "Neovim mason/treesitter" 20m nvim --headless -i NONE \
            "${nvim_post[@]}" -c 'qall!' </dev/null
    fi

    # TPM (tmux plugin manager) — the tmux analog to the vim-plug step above. TPM lives at
    # $XDG_CONFIG_HOME/tmux/plugins/tpm (tmux.conf runs it from there), and install.sh never
    # updates it. update_plugins pulls new commits for every plugin; clean_plugins removes
    # plugin dirs no longer declared in tmux.conf. The bin/ scripts run standalone (no
    # attached session needed); </dev/null keeps them off the tty inside the tee pipe.
    #
    # TPM is also BOOTSTRAPPED here, not just updated. tmux.conf runs it unconditionally but
    # install.sh never clones it, so a fresh machine had a tmux.conf referencing a directory
    # that did not exist — every plugin silently absent with no error anywhere. And TPM
    # itself was never updated even where present: update_plugins moves the PLUGINS, the
    # same distinction as zinit above.
    local tpm_root="${XDG_CONFIG_HOME:-${HOME}/.config}/tmux/plugins"
    local tpm_dir="${tpm_root}/tpm"
    if (( $+commands[tmux] )); then
        # Bootstrap. `git clone` refuses a non-empty target, so the guard is "no .git" and
        # the directory is removed first when it is empty — which is exactly how this repo
        # found it: config/tmux/plugins/ held orphaned gitlinks (mode 160000 with no
        # .gitmodules), so `git clone` of the dotfiles created empty placeholder dirs that
        # no `submodule update` could ever fill. tmux plugins had never once worked.
        if [[ ! -d "${tpm_dir}/.git" ]] && (( $+commands[git] )); then
            maintain::hdr "Tmux plugin manager (TPM bootstrap)"
            [[ -d "${tpm_dir}" ]] && rmdir "${tpm_dir}" 2>/dev/null
            maintain::step "tpm clone" 5m git clone --depth 1 \
                https://github.com/tmux-plugins/tpm "${tpm_dir}" </dev/null
        fi
        if [[ -x "${tpm_dir}/bin/update_plugins" ]]; then
            maintain::hdr "Tmux plugins (TPM self-update, install, update + clean)"

            # Drop EMPTY plugin directories first. They are the residue of the orphaned
            # gitlinks described above, and they poison both remaining steps: TPM decides a
            # plugin is "Already installed" from the directory's existence alone, so install
            # skips it, and update then runs `git pull` inside something that is not a
            # repository ("cannot pull with rebase: You have unstaged changes"). rmdir, not
            # rm -rf: it refuses anything non-empty, so a real checkout can never be hit.
            local stale_plugin
            for stale_plugin in "${tpm_root}"/*(N/); do
                [[ "${stale_plugin:t}" == tpm ]] && continue
                rmdir "${stale_plugin}" 2>/dev/null
            done

            # TMUX_PLUGIN_MANAGER_PATH must be set on the tmux SERVER, not merely exported
            # into this process: TPM resolves it in scripts/helpers/plugin_functions.sh with
            # `tmux start-server\; show-environment -g TMUX_PLUGIN_MANAGER_PATH`, so a plain
            # export is invisible to it. Without the variable, update_plugins prints
            # "FATAL: Tmux Plugin Manager not configured in tmux.conf" and aborts — the
            # normal case for an unattended run, where no tmux server is up.
            #
            # A DETACHED SESSION, not a bare `start-server`. A tmux server with no sessions
            # exits immediately, taking its environment with it, so `start-server \;
            # set-environment` sets a variable on a server that is gone before TPM's own
            # `start-server` spawns a fresh, empty one — which fails in exactly the same way
            # while looking like it should have worked. Holding one throwaway session open
            # keeps the server, and its environment, alive for the three steps below.
            #
            # Named distinctively and killed afterwards, so it cannot collide with or
            # disturb a real session. Where a server is ALREADY running this just adds and
            # removes one session; -g then sets the same value tmux.conf sets anyway. The
            # trailing slash is load-bearing: TPM concatenates it with the plugin name.
            local tpm_session="maintain-tpm-$$"
            local tpm_env_ok=0
            if tmux new-session -d -s "${tpm_session}" 2>/dev/null; then
                tmux set-environment -g TMUX_PLUGIN_MANAGER_PATH "${tpm_root}/" 2>/dev/null && tpm_env_ok=1
            fi

            if (( tpm_env_ok )); then
                # --ff-only: never leave a half-merged TPM behind if the checkout was edited.
                maintain::step "tpm self-update" 5m git -C "${tpm_dir}" pull --ff-only </dev/null
                # install before update: tmux.conf declares plugins that may never have been
                # fetched, and update_plugins only moves what is already on disk.
                maintain::step "tpm install" 10m "${tpm_dir}/bin/install_plugins" </dev/null
                maintain::step "tpm" 20m "${tpm_dir}/bin/update_plugins" all </dev/null \
                    && maintain::step "tpm" 5m "${tpm_dir}/bin/clean_plugins" </dev/null
            else
                maintain::health_warn "could not start a tmux server; skipped TPM plugin update"
            fi
            tmux kill-session -t "${tpm_session}" 2>/dev/null
        fi
    fi

    # Claude Code self-updates in place. Guard to the standalone install under $HOME (the
    # native installer's ~/.local/bin): a system- or npm-managed copy can't self-update and
    # would only book a spurious failure — same contract as the mise/uv self-update guards.
    if (( $+commands[claude] )) && [[ "${commands[claude]}" == "${HOME}"/* ]]; then
        maintain::hdr "Claude Code"
        maintain::step "Claude Code" 10m claude update </dev/null
    fi

    # PowerShell profile (WSL only). Unlike everything under config/, powershell/ is
    # COPIED to Windows local disk rather than symlinked — a $PROFILE pointing at
    # \\wsl.localhost\ dies on `wsl --shutdown`, is refused by execution policy (UNC is
    # the Internet zone), and pays UNC round-trips every shell start. See
    # powershell/README.md. Consequence: repo edits do NOT reach pwsh until copied, which
    # is exactly the kind of drift this function exists to close.
    #
    # The copy is done here in zsh rather than by invoking the pwsh `dotsync` function,
    # because dotsync is DEFINED BY the profile being synced: if a bad edit breaks the
    # profile, dotsync no longer exists and the one command that could fix it is gone.
    # This path keeps working regardless.
    #
    # The file set is GLOBBED, not listed, in all three places that copy it (here,
    # dotsync in aliases.ps1, install.ps1 §3) — three hand-maintained lists in two trees
    # drift, and the drift is invisible until a newly added fragment silently never
    # deploys.
    if [[ "${HOST_OS}" == "wsl" && "${in_container}" != "true" ]] && (( $+commands[cmd.exe] )); then
        # cd to a drive path first so cmd.exe doesn't warn about a UNC cwd.
        local win_local_appdata pwsh_deploy
        win_local_appdata="$(builtin cd /mnt/c && cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')"
        [[ -n "${win_local_appdata}" ]] && win_local_appdata="$(wslpath -u "${win_local_appdata}" 2>/dev/null)"
        pwsh_deploy="${win_local_appdata}/dotfiles"

        # Only refresh an EXISTING deployment. Creating one here would leave files on disk
        # that no $PROFILE points at — linking is install.ps1's job, not this function's.
        if [[ -n "${win_local_appdata}" && -d "${pwsh_deploy}/powershell" ]]; then
            maintain::hdr "PowerShell profile sync (${pwsh_deploy})"
            {
                local f rel dest
                # local.ps1 is excluded: machine-specific, exists only in the deployment.
                # install.ps1 too: it is the bootstrap, not part of the runtime profile.
                for f in "${DOTFILES_ROOT}"/powershell/*.ps1(N.); do
                    [[ "${f:t}" == (local.ps1|install.ps1) ]] && continue
                    cp -f "${f}" "${pwsh_deploy}/powershell/${f:t}"
                done
                # Shared tool configs the profile reads at runtime; without these its env
                # vars would point back into WSL and undo the whole point of the copy.
                for rel in config/ripgrep/.ripgreprc config/mise/config.toml config/atuin config/zsh/references; do
                    [[ -e "${DOTFILES_ROOT}/${rel}" ]] || continue
                    dest="${pwsh_deploy}/${rel}"
                    mkdir -p "${dest:h}"
                    cp -rf "${DOTFILES_ROOT}/${rel}" "${dest}"
                done
            } || failures+=("pwsh profile sync")
        fi

        # The normal WSL run deliberately stops at syncing the Windows profile: a bare
        # `maintain` must not unexpectedly open a UAC dialog or update Windows packages.
        # --windows is the explicit bridge. It loads the LOCAL deployed profile (never the
        # UNC repo) and tells its maintain function both answers in advance: no bootstrap,
        # one elevated package-manager child. The PowerShell command turns a `$false`
        # function result into a native non-zero exit so this side can report it honestly.
        if (( run_windows )); then
            maintain::hdr "Windows maintenance (--windows)"
            local win_profile="${pwsh_deploy}/powershell/profile.ps1"
            if (( ! $+commands[pwsh.exe] )); then
                print -r -- "    pwsh.exe is not reachable from WSL"
                failures+=("Windows maintain (pwsh.exe unavailable)")
            elif [[ ! -r "${win_profile}" ]]; then
                print -r -- "    deployed profile missing: ${win_profile}"
                failures+=("Windows maintain (deployment unavailable)")
            else
                local win_profile_win="$(wslpath -w "${win_profile}" 2>/dev/null)"
                if [[ -z "${win_profile_win}" ]]; then
                    print -r -- "    could not translate deployed profile path for Windows"
                    failures+=("Windows maintain (path translation)")
                else
                    # Pass the Windows path as base64 rather than interpolating a quoted path
                    # into PowerShell source. This remains correct for a Windows username
                    # containing spaces or an apostrophe and never relies on pwsh argument
                    # forwarding through WSL interop.
                    local win_profile_b64="$(print -rn -- "${win_profile_win}" | base64 | tr -d '\n')"
                    pwsh.exe -NoProfile -ExecutionPolicy Bypass -Command \
                        "\$profilePath = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${win_profile_b64}')); . \$profilePath; if (-not (maintain -NoInstall -Elevate)) { exit 1 }" \
                        || failures+=("Windows maintain")
                fi
            fi
        fi
    elif (( run_windows )) && [[ "${HOST_OS}" == "wsl" && "${in_container}" != "true" ]]; then
        maintain::hdr "Windows maintenance (--windows)"
        print -r -- "    cmd.exe is not reachable from WSL; cannot locate the deployed Windows profile"
        failures+=("Windows maintain (cmd.exe unavailable)")
    elif (( run_windows )); then
        maintain::hdr "Windows maintenance (--windows)"
        print -r -- "    --windows is available only from a non-container WSL host"
        failures+=("Windows maintain (not WSL)")
    fi
    fi  # phase 2


    # ----------------------------------------------------
    # 3. GLOBAL PACKAGES & LANGUAGE CACHES
    # ----------------------------------------------------
    if maintain::phase_enabled 3; then
    print -r -- $'\n▸ [3/7] 🌐 Global Packages & Build Caches'

    # Node / JS ecosystem
    # The cache is cleared by path, not via `bun pm cache rm`: every `bun pm` subcommand
    # resolves a project root first and hard-fails ("No package.json was found", rc=1)
    # when run outside one — which is always, since `maintain` runs from wherever you
    # happen to be. The location is deterministic from BUN_INSTALL (set in .zshenv), and
    # BUN_INSTALL_CACHE_DIR overrides it when set, matching bun's own resolution order.
    if (( $+commands[bun] )); then
        maintain::hdr "Bun (upgrade & cache clear)"
        maintain::step "bun" 10m bun upgrade
        rm -rf "${BUN_INSTALL_CACHE_DIR:-${BUN_INSTALL:-${HOME}/.bun}/install/cache}"
    fi
    # npm: the global packages, then the caches npm's own `cache clean` structurally cannot
    # reach.
    #
    # `npm cache clean --force` works — it just has a far narrower scope than the name
    # suggests. It empties _cacache inside the ONE directory `npm config get cache` names,
    # and nothing else. Three trees therefore grow forever, and this ran weekly for months
    # while they did (measured 2026-09-13, against a 48K _cacache):
    #
    #   $cache/_npx   1.2G  npx's package cache — a SIBLING of _cacache, never cleaned
    #   $cache/.npm   5.3G  a nested orphan, from a run whose HOME resolved to $cache itself
    #   ~/.npm        1.0G  the pre-XDG location, dead since npm_config_cache moved to
    #                       $XDG_CACHE_HOME/npm, and unreachable by every npm command since
    #
    # All three are pure cache: regenerated on demand, never configuration. The ~/.npm
    # removal is guarded on it not BEING the live cache (both sides resolved with :A), so a
    # machine with no XDG override — where ~/.npm is what npm actually uses — is left alone
    # and only its _npx sibling is taken.
    if (( $+commands[npm] )); then
        maintain::hdr "NPM globals & cache"
        maintain::step "npm" 20m npm update -g
        npm cache clean --force || failures+=("npm cache clean")

        local npm_cache="$(npm config get cache 2>/dev/null)"
        local -a npm_orphans=()
        if [[ -n "${npm_cache}" && "${npm_cache}" != undefined && -d "${npm_cache}" ]]; then
            npm_orphans+=( "${npm_cache}/_npx"(N/) "${npm_cache}/.npm"(N/) )
            local npm_legacy="${HOME}/.npm"
            [[ "${npm_cache:A}" != "${npm_legacy:A}" ]] && npm_orphans+=( "${npm_legacy}"(N/) )
        fi
        if (( ${#npm_orphans} )); then
            local npm_orphan npm_sz
            for npm_orphan in "${npm_orphans[@]}"; do
                npm_sz="$(du -sh "${npm_orphan}" 2>/dev/null | cut -f1)"
                print -r -- "    reclaiming ${npm_orphan} (${npm_sz:-?})"
                rm -rf -- "${npm_orphan}" || failures+=("npm orphan cache")
            done
        else
            print -r -- "    ✓ no orphaned npm/npx cache trees"
        fi
    fi

    # pnpm: bump globally-installed packages, and self-update ONLY the standalone install
    # (under PNPM_HOME, set in .zshenv) — a corepack/npm-managed pnpm can't self-update and
    # would just book a spurious failure, same reasoning as the mise/uv self-update guards.
    if (( $+commands[pnpm] )); then
        maintain::hdr "pnpm (self-update, global packages & store prune)"
        [[ -n "${PNPM_HOME}" && "${commands[pnpm]}" == "${PNPM_HOME}"/* ]] && maintain::step "pnpm self-update" 10m pnpm self-update </dev/null
        maintain::step "pnpm globals" 20m pnpm update -g </dev/null
        # The content-addressable store keeps every package version ever linked into any
        # project, including ones no lockfile references any more. Nothing else reclaims it;
        # the PowerShell side has done this since maintain.ps1 was written.
        maintain::step "pnpm store prune" 10m pnpm store prune </dev/null
    fi

    if (( $+commands[yarn] )) && [[ "$(yarn --version 2>/dev/null)" == 1.* ]]; then
        maintain::hdr "Yarn v1 globals & cache"
        maintain::step "yarn" 20m yarn global upgrade \
            && maintain::step "yarn" 10m yarn cache clean
    fi

    # Python ecosystem. `uv self update` refuses (exit 2) on anything not installed by
    # the standalone script, and "lives under $HOME" is NOT sufficient to prove that: a
    # mise-managed uv sits at ~/.local/share/mise/installs/uv/…, passes the $HOME test,
    # and then fails on every single run. Exclude version-manager install trees, and let
    # the owning manager (mise upgrade, above) do the updating there.
    if (( $+commands[uv] )); then
        maintain::hdr "UV (self-update, tools & cache prune)"
        if [[ "${commands[uv]}" == "${HOME}"/* && "${commands[uv]}" != *"/mise/installs/"* \
           && "${commands[uv]}" != *"/asdf/installs/"* ]]; then
            maintain::step "uv self-update" 10m uv self update
        fi
        maintain::step "uv tools" 20m uv tool upgrade --all
        maintain::step "uv cache" 10m uv cache prune
    fi
    (( $+commands[pipx] )) && { maintain::hdr "Pipx packages"; maintain::step "pipx" 20m pipx upgrade-all }
    (( $+commands[pip] ))  && { maintain::hdr "Pruning Pip cache"; pip cache purge 2>/dev/null || true }

    # pynvim (vim/neovim Python provider): install.sh installs it but never bumps it. Upgrade
    # with the python's OWN pip, not `uv pip`: uv rejects `--user` outright ("pip's --user is
    # unsupported") and `uv pip` with no active venv errors too. The mise-managed python is
    # user-owned, so a plain `pip install --upgrade` writes to its site-packages with no
    # --user flag and no sudo. Guarded on pynvim already being importable, so we upgrade an
    # existing provider rather than installing one on a machine that never had it.
    if (( $+commands[mise] )) && mise exec -- python -c 'import pynvim' 2>/dev/null; then
        maintain::hdr "pynvim (vim python provider)"
        maintain::step "pynvim" 10m mise exec -- python -m pip install --upgrade pynvim </dev/null
    fi

    # PHP ecosystem
    (( $+commands[composer] )) && { maintain::hdr "Composer globals"; maintain::step "composer" 20m composer global update }

    # Compiled Languages (Go / Rust)
    (( $+commands[go] ))    && { maintain::hdr "Cleaning Go build cache"; go clean -cache -testcache || failures+=("go cache") }
    (( $+commands[cargo] )) && (( $+commands[cargo-cache] )) && { maintain::hdr "Cargo cache prune"; maintain::step "cargo cache" 10m cargo cache --remove-dir git-db,registry-sources }
    # cargo-update refreshes whatever is still cargo-installed. dua-cli, qsv and yazi used
    # to be here; all three now come from gh-r, so this only covers leftovers.
    #
    # It is also INSTALLED here when missing, which is why the step below is no longer dead
    # code: nothing in install.sh ever provided cargo-update, so the $+commands guard had
    # never once passed on a machine built from this repo and the whole step was a no-op.
    # --locked so the build uses the crate's own pinned dependency set. One ~5 minute
    # compile on a fresh machine, never again.
    if (( $+commands[cargo] )) && (( ! $+commands[cargo-install-update] )); then
        maintain::hdr "Installing cargo-update (first run only)"
        maintain::step "cargo-update install" 20m cargo install --locked cargo-update </dev/null
        rehash
    fi
    (( $+commands[cargo-install-update] )) && { maintain::hdr "Cargo-installed binaries"; maintain::step "cargo install-update" 30m cargo install-update -a }

    # Atuin history sync — the atuin BINARY already updates via the zinit reset (phase 2);
    # this pushes/pulls shell history against the sync server. Guard on the session file:
    # without a login `atuin sync` exits non-zero ("you are not logged in"), which would
    # book a spurious failure on every machine that doesn't use atuin's sync service.
    if (( $+commands[atuin] )) && [[ -f "${XDG_DATA_HOME:-${HOME}/.local/share}/atuin/session" ]]; then
        maintain::hdr "Atuin history sync"
        maintain::step "atuin sync" 5m atuin sync </dev/null
    fi

    # Downloaded-toolchain caches: node-gyp headers, and the browser builds Playwright and
    # Puppeteer fetch. Each tool downloads a new versioned directory and never removes the
    # one it replaced, so they accumulate one generation per upgrade indefinitely — 2.0G
    # across the three here (measured 2026-09-13). Every byte is re-downloaded on demand.
    #
    # KEEP-NEWEST rather than prune-by-age: mtime says when a directory was written, not
    # whether anything still uses it, and a project pinned to an older Playwright would have
    # its browsers deleted out from under it by an age rule. The newest revision per browser
    # is the one a fresh `npx playwright install` resolves to.
    maintain::hdr "Stale toolchain caches"
    local -i tc_removed=0
    local -a tc_super=()
    local tc_cache="${XDG_CACHE_HOME:-${HOME}/.cache}"

    # node-gyp: one directory per node version, named by version. Keep whatever mise has
    # installed (the versions that can actually build today) plus the newest entry, so a
    # non-mise node still leaves something behind.
    if [[ -d "${tc_cache}/node-gyp" ]]; then
        local -a gyp_all=( "${tc_cache}"/node-gyp/*(N/:t) )
        if (( ${#gyp_all} > 1 )); then
            local -aU gyp_keep=()
            # `mise ls --installed node` prints "node  24.21.0  <config>  lts" — whitespace
            # separated, version in field 2. Same (z)-split idiom as maintain::mise_prune.
            if (( $+commands[mise] )); then
                local gyp_line
                for gyp_line in ${(f)"$(mise ls --installed node 2>/dev/null)"}; do
                    gyp_keep+=( "${${(z)gyp_line}[2]}" )
                done
            fi
            gyp_keep=( ${gyp_keep:#} )
            # Newest on disk as a floor, so a machine whose node is not mise-managed still
            # keeps a usable set rather than having every header directory removed.
            gyp_keep+=( ${${(On)gyp_all}[1]} )
            local gyp_v
            for gyp_v in ${gyp_all:|gyp_keep}; do
                print -r -- "    node-gyp: removing headers for ${gyp_v}"
                rm -rf -- "${tc_cache}/node-gyp/${gyp_v}" && (( tc_removed++ ))
            done
        fi
    fi

    # Playwright / Puppeteer: "<name>-<version>" directories, keep the newest per name.
    #
    # The two lay out differently and BOTH have to work:
    #   ms-playwright/chromium-1228              one level, integer revision
    #   puppeteer/chrome/linux-146.0.7680.153    two levels, dotted version
    # so the parent directories are enumerated rather than assumed — puppeteer's browser
    # subdirectory is the grouping parent, not `puppeteer` itself. An earlier single-level
    # loop matched nothing under puppeteer and silently pruned it forever.
    #
    # Group = everything before the first dash-then-digit, via `%%-[0-9]*` (longest suffix).
    # A greedy `%-*` is wrong for the dotted form: it would split linux-146.0.7680.153 into
    # group "linux-146.0.7680", making every patch release its own group and pruning nothing.
    # chromium and chromium_headless_shell still separate correctly, since the underscore is
    # not a dash. Entries with no version suffix (ms-playwright keeps a stray `b/`) fall in
    # no group and are never touched.
    #
    # The `n` sort flag compares embedded digit runs numerically, so 1228 beats 1223 and
    # .153 beats .99 — plain string order gets both wrong.
    local tc_parent tc_name tc_group
    local -a tc_parents=( "${tc_cache}/ms-playwright"(N/) "${tc_cache}"/puppeteer/*(N/) )
    for tc_parent in "${tc_parents[@]}"; do
        local -a tc_versioned=( "${tc_parent}"/*-[0-9]*(N/:t) )
        (( ${#tc_versioned} )) || continue
        local -aU tc_groups=( ${tc_versioned%%-[0-9]*} )
        for tc_group in "${tc_groups[@]}"; do
            local -a tc_revs=( ${(On)${(M)tc_versioned:#${tc_group}-[0-9]*}} )
            (( ${#tc_revs} > 1 )) || continue
            # REPORTED, NOT DELETED. Keep-newest is the right rule for finding superseded
            # revisions and the wrong rule for acting on them: a project pinned to an older
            # Playwright needs exactly the revision this would remove, and the first sign
            # would be a test run failing to launch a browser. It re-downloads, so the cost
            # is minutes rather than data — but it is still a surprise nobody asked for.
            # node-gyp above stays automatic because it is keyed to the node versions mise
            # actually has installed, not to "newest wins".
            for tc_name in "${tc_revs[@]:1}"; do
                tc_super+=( "${tc_parent:t}/${tc_name}" )
            done
        done
        unset tc_groups
    done
    if (( ${#tc_super} )); then
        local tc_bytes=0 tc_one
        for tc_one in "${tc_super[@]}"; do
            tc_bytes=$(( tc_bytes + $(command du -sb "${tc_cache}/${tc_one}" 2>/dev/null | cut -f1) ))
        done
        maintain::health_warn "${#tc_super} superseded browser revision(s) ($(( tc_bytes / 1048576 ))M) — kept, a pinned project may still need them"
        for tc_one in "${tc_super[@]}"; do print -r -- "        ${tc_cache}/${tc_one}"; done
        print -r -- "       → if nothing pins an old version: rm -rf the paths above"
    fi
    (( tc_removed || ${#tc_super} )) || print -r -- "    ✓ no superseded toolchain downloads"
    fi  # phase 3


    # ----------------------------------------------------
    # 4. DEVOPS & CONTAINER HYGIENE (SAFE MODES)
    # ----------------------------------------------------
    if maintain::phase_enabled 4; then
    print -r -- $'\n▸ [4/7] 🐳 Containers & Cloud Tools'

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

    # Re-close both Docker autostart vectors. Autostart is off by design on this host (see
    # zsh/functions/dock.zsh and the DOCKER_AUTOSTART gate in .zshrc): an idle stack coming
    # back up on its own was a large share of what exhausted the WSL VM's RAM+swap and got
    # it hard power-cycled. Both vectors drift back ON without anyone touching them —
    #   - restart policies: tools (notably the Supabase CLI) rewrite containers to
    #     unless-stopped behind your back, so the next dockerd start drags the stack up;
    #   - systemd units: a docker-ce package upgrade re-enables docker.service/.socket,
    # which is exactly the kind of silent drift a maintenance pass exists to catch.
    #
    # WSL-only on purpose. On a server or desktop, containers that bring themselves back
    # after a reboot are the entire point — disabling that there would be a silent outage.
    if [[ "${HOST_OS}" == "wsl" && "${in_container}" != "true" ]] && (( $+commands[docker] )); then
        maintain::hdr "Docker autostart (keeping it off: restart=no + units disabled)"

        # Restart policies can only be rewritten while the daemon answers. When it is down
        # (the normal state here) there is nothing to drift and nothing to fix.
        if (( ${#docker_cmd} )); then
            local -a all_containers
            all_containers=( ${(f)"$("${docker_cmd[@]}" ps -aq 2>/dev/null)"} )
            if (( ${#all_containers} )); then
                if "${docker_cmd[@]}" update --restart=no "${all_containers[@]}" >/dev/null; then
                    print -r -- "  ${#all_containers} container(s) pinned to restart=no"
                else
                    failures+=("docker restart-policy pin")
                fi
            else
                print -r -- "  no containers to pin"
            fi
        else
            print -r -- "  daemon not running — restart policies left as-is"
        fi

        # The units are independent of the daemon being up, so this runs either way.
        if (( $+commands[systemctl] && can_sudo )); then
            local -a autostart_units
            local unit
            for unit in docker.service docker.socket containerd.service; do
                [[ "$(systemctl is-enabled "${unit}" 2>/dev/null)" == "enabled" ]] \
                    && autostart_units+=("${unit}")
            done
            if (( ${#autostart_units} )); then
                if "${sudo_cmd[@]}" systemctl disable "${autostart_units[@]}" &>/dev/null; then
                    print -r -- "  disabled at boot: ${autostart_units[*]}"
                else
                    failures+=("docker unit disable")
                fi
            else
                print -r -- "  units already disabled at boot"
            fi
        fi
    fi


    fi  # phase 4


    # ----------------------------------------------------
    # 5. SYSTEM CLEANUP & DOCUMENTATION REFRESH
    # ----------------------------------------------------
    if maintain::phase_enabled 5; then
    print -r -- $'\n▸ [5/7] 🧹 System Cleanup & Docs'

    (( $+commands[tldr] )) && { maintain::hdr "Updating tldr pages"; maintain::step "tldr" 5m tldr --update }

    (( $+commands[mise] )) && { maintain::hdr "mise (prune superseded tool versions)"; maintain::mise_prune || failures+=("mise prune") }

    # Nix store garbage collection (only when nix is installed)
    (( $+commands[nix-collect-garbage] )) && { maintain::hdr "Nix store garbage collection"; nix-collect-garbage -d || failures+=("nix gc") }

    # Safely remove broken symlinks in local user bin directory
    if [[ -d "${HOME}/.local/bin" ]]; then
        maintain::hdr "Cleaning broken symlinks in ~/.local/bin"
        find -L "${HOME}/.local/bin" -maxdepth 1 -type l -exec rm -f {} + 2>/dev/null
    fi

    # Linux AND WSL — macOS handles all of this itself; devcontainers skip it entirely
    # (ephemeral filesystem).
    #
    # WSL used to be excluded here along with darwin, on the reasoning that it has no real
    # disk to TRIM and no desktop trash to empty. That is true of fstrim and of the desktop
    # databases further down, but NOT of the journal: WSL runs systemd, journald logs to
    # /var/log/journal exactly as on metal, and nothing ever vacuumed it. This box had
    # accumulated 679M under a cleanup step that claimed to cap it at 500M. Coredumps and
    # /var/crash are real on WSL for the same reason.
    #
    # fstrim stays linux-only below: against a virtual disk it is at best a no-op and the
    # host-side reclaim it would enable is reported, not performed, by phase 6.
    if [[ "${HOST_OS}" == (linux|wsl) && "${in_container}" != "true" ]]; then
        if [[ "${HOST_OS}" == "linux" ]] && (( $+commands[fstrim] && can_sudo )); then
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

    # /tmp sweep. Most distributions ship systemd-tmpfiles with a 10-day age rule, but that
    # only fires where the timer is enabled — it is not under WSL, and not in a container —
    # so build debris, extracted archives and editor scratch files sit there until reboot.
    # The PowerShell side has swept %TEMP% on the same 30-day rule since it was written.
    #
    # Scoped hard: -uid only, mindepth 1, nothing newer than 30 days. Running as root would
    # make this a system-wide /tmp wipe, which is emphatically not what a user maintenance
    # pass should do, so it is skipped there. X11/Wayland/systemd sockets and the private
    # per-service directories are left alone by the -uid filter plus their own mtimes.
    if [[ -d /tmp ]] && (( EUID != 0 )); then
        maintain::hdr "Sweeping /tmp (own files, >30 days)"
        find /tmp -mindepth 1 -maxdepth 1 -uid "${UID}" -mtime +30 \
            -exec rm -rf {} + 2>/dev/null
    fi
    fi  # phase 5


    # ----------------------------------------------------
    # 6. DIAGNOSTICS, INTEGRITY & SECURITY
    # ----------------------------------------------------
    if maintain::phase_enabled 6; then
    print -r -- $'\n▸ [6/7] 🩺 Health, Integrity & Security'

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

    # XDG compliance. Same contract as the PATH-shadow check above: read-only, and a finding
    # is a thing for a human to judge rather than a broken step — deciding whether ~/.rustup
    # is dead weight or the only copy is exactly the judgement this cannot make for you.
    #
    # --quiet here: the verdict line plus the summary entry is what a maintenance pass needs,
    # and it skips a ~1s du sweep of $HOME that the disk report already covers. Run the bare
    # `xdg-audit` for the per-finding detail and the fix for each.
    if (( $+functions[xdg_audit] )); then
        maintain::hdr "XDG compliance"
        local xdg_verdict
        xdg_verdict="$(xdg_audit --quiet 2>/dev/null)"
        xdg_verdict="${xdg_verdict##*$'\n'}"
        if [[ "${xdg_verdict}" == *finding* ]]; then
            maintain::health_warn "${xdg_verdict} — run 'xdg-audit' for detail"
        elif [[ -n "${xdg_verdict}" ]]; then
            print -r -- "    ✓ ${xdg_verdict}"
        fi
    fi

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
        maintain::health_warn "${#dangling} unexpected broken symlink(s)"
        print -rl -- ${${dangling[@]}/#${HOME}/~}
    else
        print -r -- "    ✓ no unexpected broken symlinks"
    fi

    # Dotfiles integrity (read-only). Repo root resolves through the ZDOTDIR symlink — two :h
    # hops, because the link source is <repo>/config/zsh, not <repo>/zsh. Flag any
    # managed target that exists but is NOT a symlink back into the repo (drift — usually an
    # app rewrote a symlinked file), and warn on uncommitted/unpushed repo state. The list
    # mirrors a core subset of install.sh's SHARED_LINKS/ZSH_LINKS — keep in sync if it changes.
    local dotf="${ZDOTDIR:A:h:h}"
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
                (( drift++ )); maintain::health_warn "drift: ${mt/#${HOME}/~} no longer links into the repo"
            fi
        done
        (( drift )) && print -r -- "    → run install.sh to repair managed symlinks"
        (( drift == 0 )) && print -r -- "    ✓ managed symlinks intact"
        if (( $+commands[git] )); then
            if [[ -n "$(git -C "${dotf}" status --porcelain 2>/dev/null)" ]]; then
                maintain::health_warn "~/.dotfiles has uncommitted changes"
            else
                print -r -- "    ✓ ~/.dotfiles working tree clean"
            fi
            local unpushed="$(git -C "${dotf}" log --oneline @{u}.. 2>/dev/null | wc -l)"
            unpushed="${unpushed// /}"
            (( unpushed > 0 )) && maintain::health_warn "~/.dotfiles has ${unpushed} unpushed commit(s)"
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
            maintain::health_warn "pending config merges (review & merge):"
            print -r -- "${merges}" | while IFS= read -r sl; do print -r -- "        ${sl}"; done
        fi
        if (( can_sudo )); then
            local audit="$("${sudo_cmd[@]}" dpkg --audit 2>/dev/null)"
            [[ -n "${audit}" ]] && { (( pkg_issues++ )); maintain::health_warn "dpkg --audit reported broken package state (run: sudo dpkg --audit)" }
        fi
        local sec="$(LANG=C apt-get -s upgrade 2>/dev/null | grep -ciE '^Inst .*securi')"
        (( sec > 0 )) && { (( pkg_issues++ )); maintain::health_warn "${sec} pending security update(s) — run apt full-upgrade" }
        if (( $+commands[apt-mark] )); then
            local held="$(apt-mark showhold 2>/dev/null)"
            if [[ -n "${held}" ]]; then
                local -a held_packages=( ${(f)held} )
                maintain::health_warn "held apt package(s) will not be upgraded: ${(j:, :)held_packages}"
            else
                print -r -- "    ✓ no held apt packages"
            fi
        fi
        # `apt-get -s` only recognizes updates whose package description happens to contain
        # “security”. Ubuntu Pro has the authoritative repository-coverage view, including
        # pending ESM updates and third-party/unknown package origins. Print counts only —
        # never package names — and keep it advisory because ESM availability is not a broken
        # package state or an instruction to enroll in Pro.
        if (( $+commands[pro] && $+commands[python3] )); then
            local pro_summary
            pro_summary="$(pro security-status --format json 2>/dev/null | python3 -c '
import json, sys
summary = json.load(sys.stdin).get("summary", {})
standard = int(summary.get("num_standard_security_updates", 0))
apps = int(summary.get("num_esm_apps_updates", 0))
infra = int(summary.get("num_esm_infra_updates", 0))
third_party = int(summary.get("num_third_party_packages", 0))
unknown = int(summary.get("num_unknown_packages", 0))
reboot = bool(summary.get("reboot_required", False))
needs_review = standard > 0 or apps > 0 or infra > 0 or unknown > 0 or reboot
print(f"standard={standard} esm-apps={apps} esm-infra={infra} third-party={third_party} unknown={unknown} reboot={str(reboot).lower()} review={int(needs_review)}")
' 2>/dev/null)"
            if [[ -n "${pro_summary}" ]]; then
                print -r -- "    Ubuntu security coverage: ${pro_summary% review=*}"
                [[ "${pro_summary}" == *'review=1' ]] && maintain::health_warn "Ubuntu security-status reports updates, unknown packages, or a reboot requirement"
            else
                maintain::health_warn "could not read Ubuntu security-status"
            fi
        fi
        [[ "${HOST_LOCATION:-}" == "server" ]] && (( ! $+commands[unattended-upgrade] )) && print -r -- "    ℹ️ unattended-upgrades not installed (recommended on servers)"
        (( pkg_issues == 0 )) && print -r -- "    ✓ no pending config merges, broken packages, or security updates"
    elif (( $+commands[pacman] )); then
        local -a pacnew=( /etc/**/*.pacnew(N) /etc/**/*.pacsave(N) )
        if (( ${#pacnew} )); then
            maintain::health_warn "pending pacman config merges:"; print -rl -- ${pacnew[@]/#/        }
        else
            print -r -- "    ✓ no .pacnew/.pacsave to merge"
        fi
    else
        print -r -- "    (no apt/pacman on this host)"
    fi

    # Unit failures are relevant on desktops and WSL as much as on servers: this host's
    # memory guardrails and cron-based jobs can be dead while package updates are green.
    # Do not start, enable, or restart anything here; this is an operational report only.
    if [[ "${in_container}" != "true" ]] && [[ -d /run/systemd/system ]] && (( $+commands[systemctl] )); then
        maintain::hdr "Systemd health"
        local failed_units="$(systemctl list-units --failed --no-legend --plain 2>/dev/null)"
        if [[ -n "${failed_units}" ]]; then
            maintain::health_warn "failed systemd unit(s) detected"
            local unit_line
            print -r -- "${failed_units}" | while IFS= read -r unit_line; do print -r -- "        ${unit_line}"; done
        else
            print -r -- "    ✓ no failed systemd units"
        fi

        if [[ "${HOST_OS}" == "wsl" ]]; then
            local critical_unit enabled_state active_state
            for critical_unit in memwatch.service earlyoom.service cron.service; do
                systemctl cat "${critical_unit}" >/dev/null 2>&1 || continue
                enabled_state="$(systemctl is-enabled "${critical_unit}" 2>/dev/null)"
                [[ "${enabled_state}" == enabled || "${enabled_state}" == enabled-runtime ]] || continue
                active_state="$(systemctl is-active "${critical_unit}" 2>/dev/null)"
                [[ "${active_state}" == active ]] || maintain::health_warn "${critical_unit} is enabled but ${active_state:-inactive}"
            done
        fi
    fi

    # NTP is a native-Linux health concern (WSL takes host time). Bad time breaks package
    # signatures, TLS and scheduled jobs, so report it without attempting to reconfigure it.
    if [[ "${HOST_OS}" == "linux" && "${in_container}" != "true" ]] && (( $+commands[timedatectl] )); then
        maintain::hdr "Time synchronization"
        local ntp_sync="$(timedatectl show -p NTPSynchronized --value 2>/dev/null)"
        if [[ "${ntp_sync}" == yes ]]; then
            print -r -- "    ✓ NTP synchronized"
        elif [[ -n "${ntp_sync}" ]]; then
            maintain::health_warn "NTP is not synchronized"
        else
            print -r -- "    (time synchronization status unavailable)"
        fi
    fi

    # Pending reboot — EVERY Debian-family host, not just servers.
    #
    # This check used to live inside the server block below, which meant the one machine
    # you actually sit in front of never saw it: phase 1 runs a full-upgrade that can pull
    # a new kernel, and the flag it drops was then read only on hosts where HOST_LOCATION
    # happens to be "server". A desktop or WSL box could carry a pending reboot for weeks
    # with the maintenance run reporting all clear. Cheap, read-only, and meaningful
    # anywhere /var/run/reboot-required exists.
    if [[ -f /var/run/reboot-required ]]; then
        maintain::hdr "Pending reboot"
        maintain::health_warn "REBOOT REQUIRED"
        if [[ -f /var/run/reboot-required.pkgs ]]; then
            local pkgs="$(head -10 /var/run/reboot-required.pkgs | tr '\n' ' ')"
            print -r -- "      Packages: ${pkgs}"
        fi
    fi

    # The server-only status block that used to sit here — UFW, Fail2Ban, Certbot expiry,
    # needrestart, journal error counts, Docker health — has moved to phase 7 and its
    # service-audit. Two reasons it had to move:
    #
    #   1. It was gated on HOST_LOCATION == "server", so the machine you sit in front of
    #      never saw any of it. An inactive firewall or an expired certificate is not less
    #      interesting on a desktop.
    #   2. Gating on a host ROLE was the wrong axis entirely. What decides whether a UFW
    #      check makes sense is whether ufw is installed, not what kind of box this is.
    #      service-audit gates every check on the thing it inspects existing, so the same
    #      pass is correct on a WSL laptop and on a 38-vhost web server.
    #
    # Nothing was dropped; it all runs in more places than before.

    # WSL runtime/kernel updates live on the WINDOWS side: `wsl --update` targets the WSL2
    # platform itself and cannot run from inside the distro (apt only updates the Ubuntu
    # userland). Surface it as a reminder — informational, never a recorded failure.
    if [[ "${HOST_OS}" == "wsl" ]]; then
        maintain::hdr "WSL runtime & storage"
        print -r -- "    ℹ️ Run 'wsl --update' in Windows PowerShell to update the WSL kernel/runtime."

        # The virtual disk only ever GROWS. ext4.vhdx is sparse-allocated: deleting files
        # inside the distro frees space to the distro and returns nothing to Windows, so the
        # file on the host keeps the high-water mark of everything ever written. Measured
        # here on 2026-09-13: 209G allocated against 118G actually in use — 91G that no
        # amount of cleaning INSIDE WSL can recover.
        #
        # Reported, never performed: reclaiming it needs `wsl --shutdown`, which would kill
        # the shell running this function mid-phase. The command to run is printed instead.
        #
        # Two further Windows-side leaks show up in the same place, and both ARE removable
        # from in here because they belong to sessions that no longer exist:
        #   %TEMP%/<GUID>/swap.vhdx   a crashed session's swap file, orphaned (24G here)
        #   %TEMP%/wsl-crashes/*.dmp  kernel crash dumps (140M here)
        # Still only reported — a swap.vhdx belonging to a LIVE second distro would be
        # indistinguishable without asking Windows which sessions are running, and deleting
        # one out from under a running distro is not a risk worth taking unattended.
        # zstat rather than shelling out to stat(1) per file. Loaded here, not assumed:
        # aliases.zsh loads it too, but only when the function that needs it is called, and
        # maintain::run must not depend on that having happened.
        zmodload -F zsh/stat b:zstat 2>/dev/null
        if (( $+commands[cmd.exe] && $+commands[wslpath] && $+builtins[zstat] )); then
            local win_home win_temp
            win_home="$(builtin cd /mnt/c && cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null </dev/null | tr -d '\r')"
            [[ -n "${win_home}" ]] && win_home="$(wslpath -u "${win_home}" 2>/dev/null)"

            if [[ -n "${win_home}" && -d "${win_home}" ]]; then
                # -maxdepth 3: the distro GUID directory sits directly under wsl/.
                local vhdx
                for vhdx in "${win_home}"/wsl/**/ext4.vhdx(N.); do
                    local vhdx_bytes="$(zstat +size "${vhdx}" 2>/dev/null)"
                    [[ -n "${vhdx_bytes}" ]] || continue
                    # Used bytes for / — the distro's own view of what is really occupied.
                    local used_kb="$(command df -Pk / 2>/dev/null | awk 'NR==2 {print $3}')"
                    local -i alloc_g=$(( vhdx_bytes / 1073741824 ))
                    local -i used_g=$(( used_kb / 1048576 ))
                    local -i slack_g=$(( alloc_g - used_g ))
                    print -r -- "    ℹ️ ext4.vhdx: ${alloc_g}G allocated, ${used_g}G in use"
                    if (( slack_g >= 20 )); then
                        maintain::health_warn "~${slack_g}G reclaimable from ext4.vhdx (needs a Windows-side compact)"
                        print -r -- "       wsl --shutdown"
                        print -r -- "       Optimize-VHD -Path '$(wslpath -w "${vhdx}" 2>/dev/null)' -Mode Full"
                    fi
                done

                win_temp="$(builtin cd /mnt/c && cmd.exe /c 'echo %TEMP%' 2>/dev/null </dev/null | tr -d '\r')"
                [[ -n "${win_temp}" ]] && win_temp="$(wslpath -u "${win_temp}" 2>/dev/null)"
                if [[ -n "${win_temp}" && -d "${win_temp}" ]]; then
                    # +7 days: a live session rewrites its swap continuously, so anything
                    # untouched for a week cannot belong to a running distro.
                    local -a orphan_swap=( "${win_temp}"/*/swap.vhdx(N.md+7) )
                    if (( ${#orphan_swap} )); then
                        local swap_mb=0 sf
                        for sf in "${orphan_swap[@]}"; do
                            swap_mb=$(( swap_mb + $(zstat +size "${sf}" 2>/dev/null) / 1048576 ))
                        done
                        maintain::health_warn "${#orphan_swap} orphaned swap.vhdx in %TEMP% ($(( swap_mb / 1024 ))G) — from crashed WSL sessions"
                        print -rl -- ${orphan_swap[@]/#/        }
                    fi
                    local -a wsl_dumps=( "${win_temp}"/wsl-crashes/*.dmp(N.) )
                    (( ${#wsl_dumps} )) && maintain::health_warn "${#wsl_dumps} WSL crash dump(s) in %TEMP%/wsl-crashes"
                fi
            fi
        fi
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
    # The ⚠️ above is drawn by awk in a subshell, so it can never reach health_warnings by
    # itself. Re-derive the over-threshold set here so a filesystem at 96% shows up in the
    # closing summary instead of only in the scrollback — which is precisely how a remote
    # box in this fleet reached 3.1G free without anyone noticing.
    local -a df_full=( ${(f)"$(command df -hP 2>/dev/null | awk '
        NR>1 && $1 !~ /tmpfs|devtmpfs|overlay|udev|squashfs/ && $5+0 >= 90 { printf "%s at %s (%s free)\n", $6, $5, $4 }')"} )
    df_full=( ${df_full:#} )
    local df_line
    for df_line in "${df_full[@]}"; do
        maintain::health_warn "filesystem ${df_line}"
    done
    if (( $+commands[dust] )); then
        print -r -- "    Largest paths under ~:"
        dust -d 1 -n 12 "${HOME}" 2>/dev/null | while IFS= read -r sl; do print -r -- "      ${sl}"; done
    fi

    fi  # phase 6


    # ----------------------------------------------------
    # 7. SERVICE AUDITS (WHATEVER THIS HOST ACTUALLY RUNS)
    # ----------------------------------------------------
    #
    # Phase 6 audits the MACHINE — its dotfiles, PATH, permissions, packages. This phase
    # audits the SERVICES on it, and the two want different shapes. There is no useful
    # "server" flag to gate on: hvac-portal runs nginx + MariaDB + Redis + Supervisor,
    # freeswitch runs FreeSWITCH + Postgres + Exim, guhs runs nginx + PM2, and this WSL box
    # runs none of them. So every check inside is gated on the thing it inspects existing,
    # and the same command is correct on all four.
    #
    # It lives in its own file and runs standalone as `service-audit`, like zi-audit and
    # xdg-audit — a service check is useful on a server where you would never sit through a
    # full maintain pass.
    #
    # --quiet here: the verdict plus the summary entry is what a maintenance run needs. The
    # bare `service-audit` gives the per-service detail and the fix for each finding.
    if maintain::phase_enabled 7; then
    print -r -- $'\n▸ [7/7] 🔎 Service Audits'

    if (( $+functions[service_audit] )); then
        # --no-prompt, NOT --no-sudo-at-all: the credential maintain primed at the start is
        # still used, so the root-only checks (certbot expiry, Fail2Ban jails, MariaDB
        # running config) genuinely run here rather than reporting themselves skipped.
        # What it forbids is the interactive fallback. This call is a command substitution
        # with stderr discarded, so a sudo password prompt would be invisible AND blocking —
        # the run would appear to hang for no reason anyone could see.
        local svc_verdict
        svc_verdict="$(service_audit --quiet --no-prompt 2>/dev/null)"
        svc_verdict="${svc_verdict##*$'\n'}"
        if [[ "${svc_verdict}" == *finding* ]]; then
            maintain::health_warn "${svc_verdict} — run 'service-audit' for detail"
        elif [[ -n "${svc_verdict}" ]]; then
            print -r -- "    ✓ ${svc_verdict}"
        else
            print -r -- "    (service audit produced no verdict)"
        fi
    else
        print -r -- "    (service-audit not loaded in this shell)"
    fi
    fi  # phase 7

    # Stop the sudo keep-alive before handing the terminal back (trap covers Ctrl-C).
    if [[ -n "${sudo_keepalive_pid}" ]]; then
        kill "${sudo_keepalive_pid}" 2>/dev/null
        sudo_keepalive_pid=""
    fi

    local final_df="$(command df -h / | awk 'NR==2 {print $4}')"
    local elapsed=$(( SECONDS - start ))

    print -r -- $'\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    print -r -- "✅ Maintenance Complete!"
    printf '   Elapsed:           %dm %02ds\n' $(( elapsed / 60 )) $(( elapsed % 60 ))
    print -r -- "   Storage Available: ${initial_df} ➔ ${final_df}"
    if [[ -n "${zi_report}" ]]; then
        print -r -- "   Zinit plugins:     ${zi_report}"
        local zf
        for zf in "${zi_flagged[@]}"; do print -r -- "        • ${zf}"; done
    fi
    if (( ${#failures} )); then
        print -r -- "   ✗ ${#failures} step(s) failed:"
        local f
        for f in "${failures[@]}"; do print -r -- "        • ${f}"; done
    elif (( ! ${#health_warnings} )); then
        print -r -- "   ✓ All steps completed successfully."
    fi
    if (( ${#health_warnings} )); then
        print -r -- "   ⚠️ ${#health_warnings} read-only health warning(s) require review:"
        local health_warning
        for health_warning in "${health_warnings[@]}"; do print -r -- "        • ${health_warning}"; done
    fi
    print -r -- "   Log saved to:      ${log_file}"
    print -r -- "   Run 'exec zsh' to apply updated command paths."
    print -r -- "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    return $(( ${#failures} > 0 ))
}

# Familiar name kept working; `maintain` is now the canonical entry point.
alias update-all="maintain"
