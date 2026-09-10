#!/usr/bin/env zsh
# zi-audit.zsh — verify every zi plugin installed as its .zshrc declaration says.
# Defines `zi_audit` (alias: `zi-audit`) plus its ::declared / ::usage helpers.
#
# Exists because zinit fails silently: an unknown ice aborts the ice parser and discards
# every ice after it, extract'' drops the exec bit on update, and `zi update` merges ices
# but never removes dropped ones. docs/ZINIT_UPDATE_MECHANICS.md has the measurements.
#
# Must run where zinit is loaded — ice names are validated against zinit's OWN
# ${ZINIT[ice-list]}, so an installed annex extends the audit automatically.
# Read-only with ONE exception: an interactive run offers to delete leftover ._backup
# dirs at the end. It never deletes unprompted, and never when stdout is not a tty.

# Ices zinit writes as its own bookkeeping; comparing them reports drift on every healthy
# plugin. Not readonly — this file is re-sourced during development.
typeset -ga ZI_AUDIT_BOOKKEEPING=(
    is_release url teleid light-mode .gitignore
)

# Findings needing a .zshrc edit: counted, but a wipe+reinstall cannot fix them, so they
# never reach --ids — maintain would reinstall on them forever.
typeset -ga ZI_AUDIT_LINT=(
    unknown-ice pick-no-match ver-stale atpull-noop lucid-no-wait depth-ignored has-unmet
)

# Informational only: never counted, never affect the exit code, never reach --ids.
typeset -ga ZI_AUDIT_ADVISORY=(
    zwc-orphan completion-broken completion-disabled conditional-absent
)

function zi_audit::usage() {
    print -r -- "Usage: zi-audit [-h|--help] [-q|--quiet] [--ids] [--online] [plugin ...]"
    print -r -- ""
    print -r -- "Audit installed zi plugins against their .zshrc declarations."
    print -r -- "With no arguments every declared plugin is checked."
    print -r -- ""
    print -r -- "Declaration vs. disk:"
    print -r -- "  unknown-ice        zinit does not know it; it and every ice AFTER it"
    print -r -- "                     are silently discarded (zinit.zsh:2335)"
    print -r -- "  ice-dropped        declared in .zshrc but absent from ._zinit/"
    print -r -- "  ice-stale          in ._zinit/ but no longer declared (needs a wipe)"
    print -r -- "  not-installed      declared but no plugin directory"
    print -r -- "  no-payload         only metadata, nothing was extracted"
    print -r -- "  pick-no-match      the pick'…' pattern matches no file"
    print -r -- "  not-executable     a command/program plugin's binary lacks +x"
    print -r -- "  src-missing        src'…' names a file that is absent or empty"
    print -r -- "  orphan             installed but no longer declared in .zshrc"
    print -r -- ""
    print -r -- "Did the ice actually TAKE EFFECT (registration is not enough):"
    print -r -- "  mv/cp-not-applied  the 'A -> B' destination does not exist"
    print -r -- "  bpick-mismatch     the downloaded asset does not match bpick'…'"
    print -r -- "  ver-not-applied    HEAD is not on the ref named by ver'…'"
    print -r -- "  depth-not-applied  depth'…' given but the clone is not shallow"
    print -r -- "  nocompile-ignored  nocompile set but .zwc files exist"
    print -r -- "  compile-missing    compile'…' set but no .zwc was produced"
    print -r -- "  gh-r-clone         from'gh-r' but a .git clone is present instead"
    print -r -- "  extract-noexec     extract'' suppressed the chmod and nothing is +x"
    print -r -- ""
    print -r -- "Runtime state (needs the plugin to have loaded; turbo may defer that):"
    print -r -- "  not-on-path        as'program' but its dir never reached \$path"
    print -r -- "  not-in-fpath       a completion plugin missing from \$fpath"
    print -r -- "  completion-missing blockf/creinstall plugin with no _<name> installed"
    print -r -- ""
    print -r -- "Declaration lints — real, but a reinstall cannot fix them:"
    print -r -- "  atpull-noop        atpull'%atclone' with no atclone to run"
    print -r -- "  lucid-no-wait      lucid without wait; it only silences turbo"
    print -r -- "  depth-ignored      depth'…' on gh-r; only the git path reads it"
    print -r -- "  has-unmet          has'cmd' but cmd is absent, which explains an absence"
    print -r -- "  ver-stale          (--online) pinned while a newer release matches bpick"
    print -r -- ""
    print -r -- "Advisory (marked ~, never counted, never affects the exit code):"
    print -r -- "  zwc-orphan         a .zwc whose source is gone or older than it"
    print -r -- "  completion-broken  dangling symlink in zinit's completions dir"
    print -r -- "  completion-disabled  a completion installed but turned off by zi cdisable"
    print -r -- "  conditional-absent declared inside an if that is false on this host"
    print -r -- ""
    print -r -- "Options:"
    print -r -- "  -q, --quiet   List only plugins with findings; suppress the OK lines."
    print -r -- "      --ids     Print ONLY the ids a wipe+reinstall would fix, one per"
    print -r -- "                line. For scripting; maintain repairs exactly those."
    print -r -- "                Lints and advisories are excluded."
    print -r -- "      --online  Also run ver-stale, which needs the GitHub API: one"
    print -r -- "                request per PINNED gh-r plugin, none for the rest."
    print -r -- "                Ignored with --ids. maintain passes this."
    print -r -- ""
    print -r -- "Exits non-zero if any non-advisory finding is reported."
    print -r -- "Read-only, except that an interactive run offers to delete leftover"
    print -r -- "._backup dirs at the end. Snippets are out of scope (plugins only)."
}

# Newest tag of ${1} with an asset matching bpick glob ${2}. jq, not grep: tag and asset
# must stay PAIRED. API is newest-first. Soft-fails everywhere — a check that cannot reach
# the network reports nothing, never a false finding.
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

# Emits "id<TAB>ices<TAB>cond<TAB>id-as<TAB>ice-cond" per plugin.
# ${(z)…} not a regex: ice values carry spaces and $(…), and it splits as zsh does.
# Only ice NAMES are compared, sidestepping zinit's normalisation (as'program' -> command)
# — hence editing an ice VALUE in place is an accepted blind spot.
# cond = declared inside an `if`; id-as overrides the install dir (zinit.zsh:356).
function zi_audit::declared() {
    emulate -L zsh
    setopt local_options extended_glob typeset_silent

    local zshrc="${1}"
    local line joined="" ices="" idas="" name w
    local -i cond=0 ice_cond=0
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

        (( ${#words} )) || continue
        # ${(z)} keeps a leading # as its own word. Skipping these matters: .zshrc carries
        # commented-out `if` blocks, and counting those would mark every later plugin
        # conditional for want of a matching `fi`.
        [[ "${words[1]}" == \#* ]] && continue

        # Before the >=2 guard: a bare `fi` is a single word.
        case "${words[1]}" in
            (if) (( cond++ )); continue ;;
            (fi) (( cond > 0 )) && (( cond-- )); continue ;;
        esac

        (( ${#words} >= 2 )) || continue
        [[ "${words[1]}" == (zi|zinit) ]] || continue

        case "${words[2]}" in
            (ice)
                # Depth of the ICE line, which is not the depth of the `zi load`:
                # akavel/up (.zshrc:667) picks its ices in an if/else and loads once
                # outside it, so only one branch's ices are ever live and comparing the
                # other's would be a false drop.
                ices="" idas="" ice_cond=${cond}
                for w in "${words[@]:2}"; do
                    # A trailing comment is tokenised too — stop before it.
                    [[ "${w}" == \#* ]] && break
                    # Ice name = everything before the first quote; bare ices have none.
                    # Strip a trailing '=' from the ice=value form zinit also accepts.
                    name="${w%%[\'\"]*}"
                    name="${name%=}"
                    [[ -n "${name}" ]] || continue
                    ices+="${name} "
                    [[ "${name}" == "id-as" ]] && idas="${${w#${name}}//[\'\"=]/}"
                done
                ;;
            (load|light)
                (( ${#words} >= 3 )) && print -r -- "${words[3]}	${ices% }	${cond}	${idas}	${ice_cond}"
                ices="" idas=""
                ;;
            (for)
                # `zi for` interleaves ices and ids in one command, ices applying to the id
                # that follows. A plugin id is the word carrying a / (owner/repo) or a
                # leading % (a local path); no ice NAME can, since the name stops at the
                # first quote. Unused in this .zshrc — present so a `for` block is audited
                # rather than silently invisible AND reported as an orphan.
                ices="" idas=""
                for w in "${words[@]:2}"; do
                    [[ "${w}" == \#* ]] && break
                    name="${w%%[\'\"]*}"
                    name="${name%=}"
                    [[ -n "${name}" ]] || continue
                    if [[ "${name}" == (*/*|%*) ]]; then
                        print -r -- "${name}	${ices% }	${cond}	${idas}	${ice_cond}"
                        ices="" idas=""
                    else
                        ices+="${name} "
                        [[ "${name}" == "id-as" ]] && idas="${${w#${name}}//[\'\"=]/}"
                    fi
                done
                ices="" idas=""
                ;;
            (snippet)
                ices="" idas="" ice_cond=0   # out of scope, but they still consume the ices
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
    local id ices entry rest cond idas icecond dir ice as_val pick_val src_val hit r d xpath
    local mv_val cp_val bpick_val ver_val asset ref xfrom xto newer klass backup_size
    local -i findings=0 advisories=0 checked=0 pos bad_at limit rep hard soft unloaded=0
    local -A declared seen_twice conditional idas_of
    local -a parsed report decl_ices saved dropped stale payload hits orphans zwcs comps backups

    # id -> declared ice names. A plugin declared inside an if/else (up) appears
    # twice with different ices; record that so the drop check can be skipped for it,
    # since only one branch is live and the other's ices would be false positives.
    #
    # Fields are unpacked with successive %%/# rather than ${(s.\t.)}: an ice-less
    # declaration emits an empty field, and splitting would silently drop it and shift
    # every field after it.
    parsed=( ${(f)"$(zi_audit::declared "${zshrc}")"} )
    if (( ! ${#parsed} )); then
        print -ru2 -- "zi-audit: parsed no plugins from ${zshrc} — the parse failed, or the file is not the one you think"
        return 1
    fi
    for entry in "${parsed[@]}"; do
        id="${entry%%	*}";     rest="${entry#*	}"
        ices="${rest%%	*}";    rest="${rest#*	}"
        cond="${rest%%	*}";    rest="${rest#*	}"
        idas="${rest%%	*}";    icecond="${rest#*	}"
        [[ -n "${declared[${id}]+x}" ]] && seen_twice[${id}]=1
        declared[${id}]="${ices}"
        (( ${cond:-0} )) && conditional[${id}]=1
        # Ices chosen in an if/else and loaded once outside it (akavel/up, .zshrc:667):
        # only one branch is ever live, so comparing the other's names is a false drop.
        # This is NOT covered by seen_twice, which needs two `zi load` lines to trigger.
        (( ${icecond:-0} )) && seen_twice[${id}]=1
        [[ -n "${idas}" ]] && idas_of[${id}]="${idas}"
    done

    for id in ${(ko)declared}; do
        (( ${#wanted} )) && [[ ${wanted[(Ie)${id}]} -eq 0 ]] && continue
        (( checked++ ))
        report=()
        # id-as'…' overrides the install dir (zinit.zsh:356). Without this the plugin
        # reads as both not-installed and orphaned.
        dir="${plugins_dir}/${${idas_of[${id}]:-${id}}//\//---}"
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
            # Declared inside an `if`: absence is this host failing the condition, not
            # drift. zsh-syntax-highlighting (.zshrc:469) is desktop-and-not-SSH only, so
            # without this every server and SSH session reports a false finding.
            if (( ${conditional[${id}]:-0} )); then
                report+=("conditional-absent: declared inside an if that is false here")
            else
                report+=("not-installed (no ${dir:t})")
            fi
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

            # Reset first: these locals span the loop, so an unset one carries over.
            as_val="" pick_val="" src_val="" from_val=""
            [[ -r "${dir}/._zinit/as" ]]   && as_val="$(<"${dir}/._zinit/as")"
            [[ -r "${dir}/._zinit/pick" ]] && pick_val="$(<"${dir}/._zinit/pick")"
            [[ -r "${dir}/._zinit/src" ]]  && src_val="$(<"${dir}/._zinit/src")"
            [[ -r "${dir}/._zinit/from" ]] && from_val="$(<"${dir}/._zinit/from")"

            # --- payload -----------------------------------------------------------
            payload=( ${dir}/*(ND) ${dir}/*(N.) )
            payload=( ${payload:#*/._zinit} )
            payload=( ${payload:#*/._backup} )
            (( ${#payload} )) || report+=("no-payload (nothing extracted)")

            # The canonical drift signature (ZINIT_UPDATE_MECHANICS.md:202-212).
            if [[ "${from_val}" == "gh-r" && -d "${dir}/.git" ]]; then
                report+=("gh-r-clone: from'gh-r' but a .git clone is present — it did not install the release asset")
            fi

            # extract'' also suppresses the chmod (:232-243); not-executable needs a
            # matching pick, so a pick-less plugin slips past it.
            if [[ -r "${dir}/._zinit/extract" && -z "$(<"${dir}/._zinit/extract")" ]]; then
                if [[ "${as_val}" == (command|program) ]] && (( ${#payload} )); then
                    hits=( ${dir}/*(N.x) )
                    (( ${#hits} )) || report+=("extract-noexec: extract'' set and nothing in the plugin is executable")
                fi
            fi

            # ._backup is reported once as a total at the end, not per plugin: it is on
            # nearly every gh-r plugin, so a line each buries the actual findings.

            # --- pick target exists and is executable ------------------------------
            # Only for command/program plugins: a zsh plugin's pick is a source file
            # and has no business being +x.
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
                # No "source still present" check: the source is a glob that routinely
                # still matches the result (mv'jq* -> jq'), some are self-renames
                # (mv'bd -> bd'), and excluding the destination still leaves siblings
                # like bat.1. Measured as 8 findings, all false. Do not re-add.
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

            # compile'X': the mirror image — it was asked for, so something must exist.
            if [[ -r "${dir}/._zinit/compile" ]]; then
                zwcs=( ${dir}/**/*.zwc(N) )
                (( ${#zwcs} )) || report+=("compile-missing: compile'$(<"${dir}/._zinit/compile")' set but no .zwc was produced")
            fi

            # zsh uses <source>.zwc only when NEWER; older or orphaned is dead (:343-354).
            zwcs=( ${dir}/**/*.zwc(N) )
            for hit in "${zwcs[@]}"; do
                if [[ ! -e "${hit%.zwc}" ]]; then
                    report+=("zwc-orphan: ${hit#${dir}/} has no source")
                elif [[ "${hit%.zwc}" -nt "${hit}" ]]; then
                    report+=("zwc-orphan: ${hit#${dir}/} is older than its source and is being ignored")
                fi
            done

            # --- declaration lints: real, but no reinstall can fix them -------------
            # atpull'%atclone' with nothing to re-run (:387).
            if [[ -r "${dir}/._zinit/atpull" && "$(<"${dir}/._zinit/atpull")" == "%atclone" ]]; then
                [[ -r "${dir}/._zinit/atclone" ]] || report+=("atpull-noop: atpull'%atclone' but no atclone is declared")
            fi

            # lucid silences a turbo-only message (zinit.zsh:2484); dead without wait.
            if [[ -r "${dir}/._zinit/lucid" ]]; then
                [[ -r "${dir}/._zinit/wait" && -n "$(<"${dir}/._zinit/wait")" ]] || \
                    report+=("lucid-no-wait: lucid without wait — it only silences turbo, so it is dead here")
            fi

            # depth is read only by the git clone path (zinit-install.zsh:433) (:384-386).
            if [[ -r "${dir}/._zinit/depth" && "${from_val}" == "gh-r" ]]; then
                report+=("depth-ignored: depth'$(<"${dir}/._zinit/depth")' with from'gh-r' — only the git path reads it")
            fi

            # --- runtime state -----------------------------------------------------
            # $path and completion links are written at LOAD time (zinit.zsh:1827-1836).
            # 48 of 51 declarations are turbo, so ungated this calls the whole config
            # broken in a young shell. Unloaded plugins are skipped and counted once.
            if (( ${ZINIT_REGISTERED_PLUGINS[(Ie)${id}]} )); then
                if [[ "${as_val}" == (command|program) ]]; then
                    # zinit prepends the matched pick's directory, else the plugin dir
                    # (zinit.zsh:1833) — computed the same way rather than guessed.
                    xpath="${dir}"
                    if [[ -n "${pick_val}" ]]; then
                        # Absolute picks must NOT be prefixed with the plugin dir —
                        # git-extras picks $ZPFX/bin/git-*, its atclone having installed
                        # there, so the dir zinit puts on PATH is polaris/bin and the
                        # plugin dir legitimately never joins it. Same branch as
                        # pick-no-match above; without it this fires on every such plugin.
                        if [[ "${pick_val}" == /* ]]; then
                            hits=( ${~pick_val}(N) )
                        else
                            hits=( ${~dir}/${~pick_val}(N) )
                        fi
                        (( ${#hits} )) && xpath="${hits[1]:h}"
                    fi
                    (( ${path[(Ie)${xpath}]} )) || \
                        report+=("not-on-path: ${xpath/#${HOME}/~} is loaded but absent from \$path — something later rewrote PATH")
                fi

                # creinstall links _name into the completions dir; when it silently stops,
                # completions never reinstall (:361). _[^.]## skips _rg.ps1 / _setup.py.
                comps=( ${dir}/**/_[^.]##(N.) )
                comps=( ${comps:#*/._backup/*} )
                for hit in "${comps[@]}"; do
                    [[ -e "${ZINIT[COMPLETIONS_DIR]}/${hit:t}" ]] && continue
                    # `zi cdisable` renames the link with the underscore stripped, so
                    # this shape means deliberately off, not broken.
                    if [[ -e "${ZINIT[COMPLETIONS_DIR]}/${${hit:t}#_}" ]]; then
                        report+=("completion-disabled: ${hit:t} is installed but disabled")
                    else
                        report+=("completion-missing: ${hit:t} ships with the plugin but was never installed")
                    fi
                done
            else
                (( unloaded++ ))
            fi
        fi

        # Three classes, keyed on the finding's leading name (see the arrays at the top):
        #   advisory — never counted, never affects the exit code, never reaches --ids
        #   lint     — counted, but a wipe cannot fix it, so it must not reach --ids or
        #              maintain reinstalls the plugin onto the same broken shape forever
        #   the rest — repairable, and exactly what --ids exists to list
        rep=0
        hard=0
        soft=0
        for r in "${report[@]}"; do
            klass="${r%%:*}"
            klass="${klass%% *}"
            if (( ${ZI_AUDIT_ADVISORY[(Ie)${klass}]} )); then
                (( soft++ ))
            elif (( ${ZI_AUDIT_LINT[(Ie)${klass}]} )); then
                (( hard++ ))
            else
                (( hard++, rep++ ))
            fi
        done

        if (( ids_only )); then
            (( rep )) && print -r -- "${id}"
        elif (( hard )); then
            (( findings += hard, advisories += soft ))
            print -r -- "✗ ${id}"
            for r in "${report[@]}"; do
                print -r -- "    ${r}"
            done
        elif (( soft )); then
            # ~ not ✗: maintain greps ✗ lines to decide what to repair, and an advisory is
            # explicitly not a repair request.
            (( advisories += soft ))
            (( quiet )) || { print -r -- "~ ${id}"; for r in "${report[@]}"; do print -r -- "    ${r}"; done; }
        elif (( ! quiet )); then
            print -r -- "✓ ${id}"
        fi
    done

    # --ids is a machine-readable list and nothing else: no orphan block, no summary.
    (( ids_only )) && return 0

    # --- orphans: installed but no longer declared ------------------------------
    if (( ! ${#wanted} )); then
        orphans=()
        # An id-as'…' plugin lives under its LABEL, so the dir does not reconstruct into
        # a declared id; match those by label before falling back to the id mapping.
        local -A idas_dirs=()
        for id in ${(k)idas_of}; do
            idas_dirs[${idas_of[${id}]//\//---}]=1
        done
        for d in ${plugins_dir}/*(N/); do
            [[ "${d:t}" == "_local---zinit" ]] && continue
            (( ${idas_dirs[${d:t}]:-0} )) && continue
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
    # An audit run before turbo drains sees almost nothing loaded, so say so rather than
    # letting a near-empty runtime pass read as a clean bill of health.
    (( unloaded )) && print -r -- "${unloaded} plugin(s) not loaded yet (turbo) — runtime checks skipped for those"

    # ziextract parks the previous extraction in ._backup on every gh-r update and never
    # reclaims it, so it accrues silently across the whole tree. One du over all of them
    # rather than one per plugin.
    if (( ! ${#wanted} )); then
        backups=( ${plugins_dir}/*/._backup(N/) )
        if (( ${#backups} )); then
            backup_size="${$(du -shc -- "${backups[@]}" 2>/dev/null | tail -1)%%[[:space:]]*}"
            print -r -- "${backup_size} of ._backup residue across ${#backups} plugin(s)"
        fi
    fi

    # Global runtime state, checked once rather than per plugin.
    if (( ! ${#wanted} )) && [[ -n "${ZINIT[COMPLETIONS_DIR]}" ]]; then
        # If this one line is wrong, every completion in the config is dead.
        if (( ! ${fpath[(Ie)${ZINIT[COMPLETIONS_DIR]}]} )); then
            print -r -- "✗ fpath-missing: ${ZINIT[COMPLETIONS_DIR]} is not in \$fpath — no zinit completion works"
            (( findings++ ))
        fi
        # A link whose target an update moved out from under it.
        hits=( ${ZINIT[COMPLETIONS_DIR]}/*(N@) )
        for hit in "${hits[@]}"; do
            [[ -e "${hit}" ]] || { print -r -- "~ completion-broken: ${hit:t} dangles"; (( advisories++ )); }
        done
    fi

    # maintain takes the LAST line as the verdict; keep it last, and keep the
    # "N plugin(s) checked" prefix it prints verbatim.
    local tail_note=""
    local -i rc=0
    (( advisories )) && tail_note=", ${advisories} advisory"
    if (( findings )); then
        print -r -- "${checked} plugin(s) checked — ${findings} finding(s)${tail_note}"
        rc=1
    else
        print -r -- "${checked} plugin(s) checked — all clean${tail_note}"
    fi

    # The ONE place zi-audit is not read-only, and it never acts without an answer.
    # Gated on BOTH stdin and stdout being a tty: maintain captures this function with
    # $(zi_audit --quiet --online), which makes stdout a pipe, so an unattended run can
    # never reach the prompt and can never block. --ids is machine-readable, so it is out
    # too — and it returns long before here anyway.
    if (( ! ids_only && ${#backups} )) && [[ -t 0 && -t 1 ]]; then
        print -rn -- "Delete all ${#backups} ._backup director$( (( ${#backups} == 1 )) && print -n y || print -n ies) (${backup_size})? [y/N] "
        if read -q; then
            print -r -- ""
            # Re-glob rather than trusting the list: the audit above is not instant, and
            # these paths are rm -rf targets.
            backups=( ${plugins_dir}/*/._backup(N/) )
            (( ${#backups} )) && rm -rf -- "${backups[@]}"
            print -r -- "Reclaimed ${backup_size}."
        else
            print -r -- ""
        fi
    fi
    return ${rc}
}

alias zi-audit="zi_audit"
