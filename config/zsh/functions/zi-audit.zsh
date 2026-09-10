#!/usr/bin/env zsh
# ==============================================================================
# zi-audit.zsh - Verify every zi plugin installed as its .zshrc declaration says
# ==============================================================================
# Defines `zi_audit` (alias: `zi-audit`) plus its ::declared / ::usage helpers.
#
# Why this exists: zinit fails SILENTLY in several ways that a working shell does
# not reveal. All of these were live in this config and none produced an error:
#
#   1. An unrecognised ice aborts the ice parser. zinit.zsh:2335 matches each ice
#      against ${ZINIT[ice-list]} and `|| break`s on a miss — so the unknown ice AND
#      EVERY ICE AFTER IT are discarded. `sbin` (annex-only, no annex installed) ate
#      eza's atclone and ast-grep's nocompile; `branch` (not an ice in v3.15.3) ate
#      zsh-fancy-completions' atpull. Binaries still worked, so nothing looked wrong.
#   2. `extract''` suppresses ziextract, which is also what chmods +x. A fresh
#      install lands 0755, but an UPDATE re-downloads 0644 — jq silently stopped
#      being executable on every new upstream release.
#   3. Metadata drift: a targeted `zi update` MERGES ices and never removes ones
#      dropped from .zshrc, so a retired atclone keeps firing forever.
#
# See docs/ZINIT_UPDATE_MECHANICS.md for the measurements behind each.
#
# Sourced by: .zshrc, via the `${ZDOTDIR}/functions/`*.zsh(N) loop. It must run in a
# shell where zinit is loaded, because it validates ice names against zinit's OWN
# ${ZINIT[ice-list]} rather than a hardcoded copy — so it stays correct automatically
# if an annex is ever installed to extend that list.
#
# Read-only. It never installs, updates or deletes anything.
# ==============================================================================

# Ices zinit writes into ._zinit/ as its own bookkeeping rather than because .zshrc
# declared them. Comparing these would report drift on every healthy plugin.
# Not readonly: this file is re-sourced during development, and -r would abort that.
typeset -ga ZI_AUDIT_BOOKKEEPING=(
    is_release url teleid light-mode .gitignore
)

function zi_audit::usage() {
    print -r -- "Usage: zi-audit [-h|--help] [-q|--quiet] [plugin ...]"
    print -r -- ""
    print -r -- "Audit installed zi plugins against their .zshrc declarations."
    print -r -- "With no arguments every declared plugin is checked."
    print -r -- ""
    print -r -- "Checks per plugin:"
    print -r -- "  unknown-ice    an ice zinit does not recognise — it and every ice"
    print -r -- "                 AFTER it are silently discarded (zinit.zsh:2335)"
    print -r -- "  ice-dropped    declared in .zshrc but absent from ._zinit/"
    print -r -- "  ice-stale      present in ._zinit/ but no longer declared (needs a"
    print -r -- "                 wipe — an update merges ices and cannot remove them)"
    print -r -- "  not-installed  declared but no plugin directory"
    print -r -- "  no-payload     directory holds only metadata, nothing was extracted"
    print -r -- "  pick-no-match  the pick'…' pattern matches no file"
    print -r -- "  not-executable a command/program plugin's binary lacks +x"
    print -r -- "  src-missing    src'…' names a file that is absent or empty"
    print -r -- "  orphan         installed but no longer declared in .zshrc"
    print -r -- ""
    print -r -- "Checks that an ice actually TOOK EFFECT (registration is not enough):"
    print -r -- "  mv/cp-not-applied  the 'A -> B' destination does not exist"
    print -r -- "  bpick-mismatch     the downloaded asset does not match bpick'…'"
    print -r -- "  ver-not-applied    HEAD is not on the ref named by ver'…'"
    print -r -- "  depth-not-applied  depth'…' given but the clone is not shallow"
    print -r -- "  nocompile-ignored  nocompile set but .zwc files exist"
    print -r -- ""
    print -r -- "With --online, one more (see the note at the bottom):"
    print -r -- "  ver-stale          a gh-r plugin is pinned with ver'…' while a NEWER"
    print -r -- "                     upstream release already carries a matching asset"
    print -r -- ""
    print -r -- "Options:"
    print -r -- "  -q, --quiet   List only plugins with findings; suppress the OK lines."
    print -r -- "      --ids     Print ONLY the ids of plugins a wipe+reinstall would fix,"
    print -r -- "                one per line, nothing else. For scripting (maintain uses"
    print -r -- "                it to repair exactly those). Declaration bugs a reinstall"
    print -r -- "                cannot touch (unknown-ice, pick-no-match) are excluded —"
    print -r -- "                those need a .zshrc edit, so reinstalling would loop."
    print -r -- "      --online  Additionally run ver-stale, which needs the GitHub API."
    print -r -- "                One request per PINNED gh-r plugin, none for the rest."
    print -r -- "                Ignored with --ids. maintain passes this."
    print -r -- ""
    print -r -- "Exits non-zero if any finding is reported. Read-only: never installs,"
    print -r -- "updates or deletes. Snippets are out of scope (plugins only)."
    print -r -- ""
    print -r -- "Version staleness is deliberately NOT checked for UNPINNED plugins —"
    print -r -- "\`zi update\` already compares installed against latest and skips what has"
    print -r -- "not moved. A ver'…' pin is the exact case it cannot catch: the pin is what"
    print -r -- "update honours, so a pin added to work around a broken upstream release"
    print -r -- "stays put forever once the reason for it is forgotten. That is what"
    print -r -- "--online looks for, and why it is opt-in rather than always on."
}

# Prints the newest release tag of ${1} that carries an asset matching the bpick glob
# ${2}, or nothing. Used only by the ver-stale check.
#
# jq rather than a grep over the raw JSON because the answer needs tag and asset PAIRED,
# and a release object holds its tag_name far from its assets[] names — a grep can find
# both and has no way to tell which belongs to which. The API returns newest-first, so
# the first match is the answer. Everything is soft-failed (missing curl or jq, no
# network, a rate-limited response): a check that cannot reach the network reports
# nothing rather than a false finding.
function zi_audit::newest_matching_tag() {
    local id="${1}" bpick="${2}" line tag asset
    local -a lines
    (( $+commands[curl] && $+commands[jq] )) || return 1
    [[ -n "${bpick}" ]] || return 1
    lines=( ${(f)"$(curl -fsSL --max-time 10 \
        "https://api.github.com/repos/${id}/releases?per_page=30" 2>/dev/null \
        | jq -r '.[] | .tag_name as $t | (.assets[]?.name | "\($t)\t\(.)")' 2>/dev/null)"} )
    for line in "${lines[@]}"; do
        tag="${line%%$'\t'*}"
        asset="${line#*$'\t'}"
        # Case-insensitive for the same reason as the bpick-mismatch check above.
        if [[ -n "${tag}" && "${(L)asset}" == ${~${(L)bpick}} ]]; then
            print -r -- "${tag}"
            return 0
        fi
    done
    return 1
}

# Parse .zshrc into "plugin-id<TAB>ice1 ice2 …" lines on stdout.
#
# Tokenising uses ${(z)…} — zsh's own shell-word splitter — rather than a regex,
# because ice VALUES routinely contain spaces, quotes and command substitution
# (mv'jq* -> jq', bpick"$(gh_asset …)"). ${(z)} honours quoting exactly as zsh does
# when it runs the line, so each ice stays one word whatever is inside it. The ice
# NAME is then the prefix before the first quote; only NAMES are ever compared, which
# sidesteps zinit's value normalisation (as'program' is stored as as=command).
function zi_audit::declared() {
    emulate -L zsh
    setopt local_options extended_glob typeset_silent

    local zshrc="${1}"
    local line joined="" ices="" name w
    local -a raw words

    raw=( ${(f)"$(<${zshrc})"} )

    for line in "${raw[@]}"; do
        # Join backslash continuations into one logical line before tokenising.
        if [[ "${line}" == *\\ ]]; then
            joined+="${line%\\} "
            continue
        fi
        joined+="${line}"

        # ${(z)} can choke on a syntactically incomplete fragment; skip those quietly.
        words=( ${(z)joined} ) 2>/dev/null
        joined=""

        (( ${#words} >= 2 )) || continue
        [[ "${words[1]}" == (zi|zinit) ]] || continue

        case "${words[2]}" in
            (ice)
                ices=""
                for w in "${words[@]:2}"; do
                    # A trailing comment is tokenised too — stop before it.
                    [[ "${w}" == \#* ]] && break
                    # Ice name = everything before the first quote; bare ices have none.
                    name="${w%%[\'\"]*}"
                    # Strip a trailing '=' from the ice=value form zinit also accepts.
                    name="${name%=}"
                    [[ -n "${name}" ]] && ices+="${name} "
                done
                ;;
            (load|light)
                (( ${#words} >= 3 )) && print -r -- "${words[3]}	${ices% }"
                ices=""
                ;;
            (snippet)
                ices=""   # snippets are out of scope, but they still consume the ices
                ;;
        esac
    done
}

function zi_audit() {
    emulate -L zsh
    # typeset_silent matters: without it, re-entering a `local` for a name that already
    # exists PRINTS the parameter, and the second `local -a` does not reset the array.
    # Every local below is therefore declared once, up front, and reset explicitly.
    setopt local_options extended_glob no_nomatch typeset_silent

    local -i quiet=0 ids_only=0 online=0
    local -a wanted
    local arg
    for arg in "$@"; do
        case "${arg}" in
            (-h|--help)  zi_audit::usage; return 0 ;;
            (-q|--quiet) quiet=1 ;;
            (--online)   online=1 ;;
            (--ids)      ids_only=1; quiet=1 ;;
            (-*)         print -ru2 -- "zi-audit: unknown option '${arg}'"; return 2 ;;
            (*)          wanted+=("${arg}") ;;
        esac
    done

    # Cleared after the loop, not inside the --ids branch, so the two flags commute:
    # `--ids --online` must behave the same as `--online --ids`. --ids reports only what a
    # wipe+reinstall repairs, and ver-stale is excluded from that set by design, so the
    # requests could not change its output — they would be latency and rate limit spent
    # on nothing.
    (( ids_only )) && online=0

    if [[ -z "${ZINIT[ice-list]}" ]]; then
        print -ru2 -- "zi-audit: zinit is not loaded — run this from an interactive shell"
        return 1
    fi

    local zshrc="${ZDOTDIR}/.zshrc"
    if [[ ! -r "${zshrc}" ]]; then
        print -ru2 -- "zi-audit: cannot read ${zshrc}"
        return 1
    fi

    local plugins_dir="${ZINIT[PLUGINS_DIR]:-${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/plugins}"

    # --- every local used below, declared exactly once --------------------------
    local id ices entry dir ice as_val pick_val src_val hit r d
    local mv_val cp_val bpick_val ver_val asset ref xfrom xto newer
    local -i findings=0 checked=0 pos bad_at limit rep
    local -A declared seen_twice
    local -a parsed report decl_ices saved dropped stale payload hits orphans zwcs

    # id -> declared ice names. A plugin declared inside an if/else (up) appears
    # twice with different ices; record that so the drop check can be skipped for it,
    # since only one branch is live and the other's ices would be false positives.
    parsed=( ${(f)"$(zi_audit::declared "${zshrc}")"} )
    for entry in "${parsed[@]}"; do
        id="${entry%%	*}"
        ices="${entry#*	}"
        [[ -n "${declared[${id}]}" ]] && seen_twice[${id}]=1
        declared[${id}]="${ices}"
    done

    for id in ${(ko)declared}; do
        (( ${#wanted} )) && [[ ${wanted[(Ie)${id}]} -eq 0 ]] && continue
        (( checked++ ))
        report=()
        dir="${plugins_dir}/${id//\//---}"
        decl_ices=( ${=declared[${id}]} )

        # --- unknown ices: these truncate the declaration at the first miss ---------
        pos=0
        bad_at=0
        for ice in "${decl_ices[@]}"; do
            (( pos++ ))
            if [[ "${ice}" != (${~ZINIT[ice-list]}) ]]; then
                report+=("unknown-ice '${ice}' — it and the $(( ${#decl_ices} - pos )) ice(s) after it are DISCARDED")
                bad_at=${pos}
                break
            fi
        done

        if [[ ! -d "${dir}" ]]; then
            report+=("not-installed (no ${dir:t})")
        else
            saved=( ${dir}/._zinit/*(N:t) )

            # --- declared vs saved -------------------------------------------------
            # Stops at a truncation point (already reported above) and is skipped for
            # conditionally-declared plugins, where the inactive branch would misfire.
            if (( ! ${seen_twice[${id}]:-0} )); then
                dropped=()
                limit=${#decl_ices}
                (( bad_at )) && limit=$(( bad_at - 1 ))
                for ice in "${decl_ices[@]:0:${limit}}"; do
                    [[ ${saved[(Ie)${ice}]} -eq 0 ]] && dropped+=("${ice}")
                done
                (( ${#dropped} )) && report+=("ice-dropped: ${dropped[*]}")

                stale=()
                for ice in "${saved[@]}"; do
                    [[ ${ZI_AUDIT_BOOKKEEPING[(Ie)${ice}]} -ne 0 ]] && continue
                    # zinit writes a `wait` key for EVERY plugin — empty when turbo was
                    # not requested. An empty, undeclared `wait` is bookkeeping, not a
                    # leftover from a removed ice. A non-empty one still gets compared.
                    # NB: the file is 1 byte (a bare newline), so -s would call it
                    # non-empty; $(<file) strips the trailing newline and yields "".
                    [[ "${ice}" == "wait" && -z "$(<${dir}/._zinit/wait)" ]] && continue
                    [[ ${decl_ices[(Ie)${ice}]} -eq 0 ]] && stale+=("${ice}")
                done
                (( ${#stale} )) && report+=("ice-stale: ${stale[*]} — needs a wipe, an update cannot remove these")
            fi

            # --- payload -----------------------------------------------------------
            payload=( ${dir}/*(ND) ${dir}/*(N.) )
            payload=( ${payload:#*/._zinit} )
            payload=( ${payload:#*/._backup} )
            (( ${#payload} )) || report+=("no-payload (nothing extracted)")

            # --- pick target exists and is executable ------------------------------
            # Only for command/program plugins: a zsh plugin's pick is a source file
            # and has no business being +x.
            as_val=""
            pick_val=""
            src_val=""
            [[ -r "${dir}/._zinit/as" ]]   && as_val="$(<"${dir}/._zinit/as")"
            [[ -r "${dir}/._zinit/pick" ]] && pick_val="$(<"${dir}/._zinit/pick")"
            [[ -r "${dir}/._zinit/src" ]]  && src_val="$(<"${dir}/._zinit/src")"

            if [[ "${as_val}" == (command|program) && -n "${pick_val}" ]]; then
                # A pick may be absolute ($ZPFX/bin/git-*, already expanded on disk);
                # only relative patterns get the plugin dir prepended.
                if [[ "${pick_val}" == /* ]]; then
                    hits=( ${~pick_val}(N) )
                else
                    hits=( ${~dir}/${~pick_val}(N) )
                fi
                if (( ! ${#hits} )); then
                    # Not necessarily fatal: as'command' puts the plugin dir on PATH by
                    # itself, so the binary often still resolves and the pick is a no-op.
                    report+=("pick-no-match: '${pick_val}' matches nothing (pick is a no-op)")
                else
                    for hit in "${hits[@]}"; do
                        [[ -x "${hit}" ]] || report+=("not-executable: ${hit#${dir}/}")
                    done
                fi
            fi

            # --- src'…' artifact (atclone output such as init.zsh) -----------------
            if [[ -n "${src_val}" && ! -s "${dir}/${src_val}" ]]; then
                report+=("src-missing: '${src_val}' absent or empty — its atclone did not run")
            fi

            # --- did each ice actually DO its job? ---------------------------------
            # Registering an ice and that ice taking effect are different things. The
            # checks above prove registration; these prove the observable outcome.

            # mv'A -> B' / cp'A -> B': the destination must exist.
            for ice in mv cp; do
                [[ -r "${dir}/._zinit/${ice}" ]] || continue
                mv_val="$(<"${dir}/._zinit/${ice}")"
                [[ "${mv_val}" == *"->"* ]] || continue
                xto="${mv_val##*->}"
                xto="${${xto##[[:space:]]#}%%[[:space:]]#}"
                [[ -n "${xto}" ]] || continue
                hits=( ${~dir}/${~xto}(N) )
                (( ${#hits} )) || report+=("${ice}-not-applied: '${mv_val}' — '${xto}' does not exist")
            done

            # bpick'PATTERN': the asset zinit actually downloaded (recorded in url)
            # must match the pattern, or a different asset was picked than intended.
            # Read unconditionally and reset every iteration: these locals are declared
            # once for the whole loop, so a value left over from the previous plugin would
            # otherwise be compared against this one.
            bpick_val=""
            [[ -r "${dir}/._zinit/bpick" ]] && bpick_val="$(<"${dir}/._zinit/bpick")"
            if [[ -n "${bpick_val}" && -r "${dir}/._zinit/url" ]]; then
                asset="${${"$(<"${dir}/._zinit/url")"}:t}"
                # Case-INSENSITIVE on purpose: zinit lowercases the whole URL before
                # storing it (which is also why Byron/dua-cli is recorded as
                # byron/dua-cli), so 'gping-Linux-…' comes back as 'gping-linux-…'.
                # A case-sensitive compare reports every mixed-case asset as a mismatch.
                if [[ -n "${bpick_val}" && -n "${asset}" && "${(L)asset}" != ${~${(L)bpick_val}} ]]; then
                    report+=("bpick-mismatch: downloaded '${asset}' but bpick is '${bpick_val}'")
                fi
            fi

            # ver'X': the checkout must actually be on X (branch or tag).
            ver_val=""
            [[ -r "${dir}/._zinit/ver" ]] && ver_val="$(<"${dir}/._zinit/ver")"
            if [[ -n "${ver_val}" && -d "${dir}/.git" ]]; then
                ref="$(command git -C "${dir}" rev-parse --abbrev-ref HEAD 2>/dev/null)"
                [[ "${ref}" == "HEAD" ]] && ref="$(command git -C "${dir}" describe --tags --exact-match 2>/dev/null)"
                [[ "${ref}" == "${ver_val}" ]] || report+=("ver-not-applied: ver'${ver_val}' but HEAD is '${ref:-unknown}'")
            fi

            # ver'X' on a gh-r plugin is a PIN, and `zi update` honours it forever — so a
            # pin added to route around one broken upstream release becomes permanent the
            # moment its reason is forgotten. Flag it as soon as a NEWER release carries a
            # matching asset, i.e. as soon as the pin has outlived its cause. Keyed on
            # is_release (zinit writes it only for from'gh-r'), so git plugins pinned to a
            # branch are untouched.
            if (( online )) && [[ -n "${ver_val}" && -r "${dir}/._zinit/is_release" ]]; then
                newer="$(zi_audit::newest_matching_tag "${id}" "${bpick_val}")"
                if [[ -n "${newer}" && "${newer}" != "${ver_val}" ]]; then
                    report+=("ver-stale: pinned to ver'${ver_val}' but '${newer}' already has an asset matching bpick — drop the pin")
                fi
            fi

            # depth'N': the clone must actually be shallow.
            if [[ -r "${dir}/._zinit/depth" && -d "${dir}/.git" ]]; then
                if [[ "$(command git -C "${dir}" rev-parse --is-shallow-repository 2>/dev/null)" != "true" ]]; then
                    report+=("depth-not-applied: depth'$(<"${dir}/._zinit/depth")' but the clone is not shallow")
                fi
            fi

            # nocompile: nothing in the plugin may have been byte-compiled.
            if [[ -r "${dir}/._zinit/nocompile" ]]; then
                zwcs=( ${dir}/**/*.zwc(N) )
                (( ${#zwcs} )) && report+=("nocompile-ignored: ${#zwcs} .zwc present (${zwcs[1]:t})")
            fi
        fi

        # A finding is repairable by wipe+reinstall UNLESS it is a declaration bug that a
        # reinstall cannot touch: an unrecognised ice, a pick matching nothing, or a pin
        # upstream has outgrown. Those need a .zshrc edit, and reinstalling on them would
        # loop forever — a ver-stale plugin in particular reinstalls perfectly happily,
        # onto the same pinned tag, every single run.
        rep=0
        for r in "${report[@]}"; do
            [[ "${r}" == unknown-ice* || "${r}" == pick-no-match* || "${r}" == ver-stale* ]] && continue
            (( rep++ ))
        done

        if (( ids_only )); then
            (( rep )) && print -r -- "${id}"
        elif (( ${#report} )); then
            (( findings += ${#report} ))
            print -r -- "✗ ${id}"
            for r in "${report[@]}"; do
                print -r -- "    ${r}"
            done
        elif (( ! quiet )); then
            print -r -- "✓ ${id}"
        fi
    done

    # --ids is a machine-readable list and nothing else: no orphan block, no summary.
    (( ids_only )) && return 0

    # --- orphans: installed but no longer declared ------------------------------
    if (( ! ${#wanted} )); then
        orphans=()
        for d in ${plugins_dir}/*(N/); do
            [[ "${d:t}" == "_local---zinit" ]] && continue
            id="${${d:t}//---//}"
            [[ -n "${declared[${id}]+x}" ]] || orphans+=("${d:t}")
        done
        if (( ${#orphans} )); then
            (( findings += ${#orphans} ))
            print -r -- "✗ orphans (installed, not declared in .zshrc):"
            for d in "${orphans[@]}"; do
                print -r -- "    ${d}"
            done
        fi
    fi

    print -r -- ""
    if (( findings )); then
        print -r -- "${checked} plugin(s) checked — ${findings} finding(s)"
        return 1
    fi
    print -r -- "${checked} plugin(s) checked — all clean"
    return 0
}

alias zi-audit="zi_audit"
