#!/usr/bin/env zsh
# ==============================================================================
# xdg-audit — report which application state in $HOME is, or could be, XDG-relocated.
#
# WHY THIS EXISTS
#
# The XDG migration in this repo is real but half-finished, and nothing noticed. .zshenv
# exports seventeen relocations (RUSTUP_HOME, CLAUDE_CONFIG_DIR, YARN_CACHE_FOLDER, …) and
# every one of them is correct — but exporting a variable does not MOVE anything. The legacy
# path is left exactly where it was, and from then on there are two plausible readings of it
# and no way to tell them apart by looking:
#
#   • the tool moved, and what remains is dead weight            → safe to delete
#   • the variable points somewhere that does not exist, and the
#     legacy path is still the only copy of the data             → deleting it loses data
#
# Telling them apart is the core of what this prints, because guessing wrong in the second
# direction deletes the only copy. The machine this was written against had four of the
# first kind (~/.claude, ~/.codex, ~/.rustup, ~/.yarn — all genuinely superseded) and none
# of the second, but the check is cheap and the failure it guards against is unrecoverable.
#
# An early draft got exactly this backwards. It tried to be clever about file-valued
# variables — "if the target looks like a file, test its parent directory instead", detected
# with `${target} == *.*` — and RUSTUP_HOME=~/.config/.rustup matched that pattern on the
# dot in `.config`. It tested ~/.config, found it full, and declared 8.1M of rustup
# toolchains safe to delete. See xdg_audit::classify for what replaced it.
#
# WHY THE CLASSIFICATION IS CURATED
#
# There is no way to ask an application whether it honours XDG. No manifest, no flag, no
# convention beyond documentation. So class 2 (relocatable, not yet declared) is a
# hand-maintained table and always will be.
#
# Class 1 is NOT hand-maintained, and that is the point: it derives itself from the
# environment, so every relocation added to .zshenv is audited from the moment it is
# exported, with nothing to keep in sync here.
#
# KEEP CLASS 3 SHORT
#
# Same reasoning as maintain::path_dupes' allowlist (see its header): a report that lists
# things you cannot act on is a report you learn to scroll past, and a report you scroll
# past still looks like coverage while providing none. Every entry in the ignore list is
# something with NO env var to redirect it — bash's hardcoded rc files, system-written
# markers, ~/.atuin/logs. If a tool later gains XDG support, its entry moves to class 2.
#
# Strictly read-only. It prints findings and the exact fix; it removes nothing, ever.
# ==============================================================================

# Relocations this repo declares, as VAR:legacy-path pairs. The var half is read from the
# live environment (so it reflects what .zshenv actually exported on THIS host); the legacy
# half is the path the tool used before the var existed, which cannot be derived and is
# therefore written down.
#
# Entries are only reported when the legacy path still exists, so listing a var that this
# machine does not set costs nothing.
typeset -gA XDG_AUDIT_DECLARED=(
    RUSTUP_HOME                   '.rustup'
    CARGO_HOME                    '.cargo'
    CLAUDE_CONFIG_DIR             '.claude'
    CODEX_HOME                    '.codex'
    GNUPGHOME                     '.gnupg'
    PASSWORD_STORE_DIR            '.password-store'
    YARN_CACHE_FOLDER             '.yarn'
    VOLTA_HOME                    '.volta'
    PNPM_HOME                     '.pnpm'
    KERAS_HOME                    '.keras'
    PARALLEL_HOME                 '.parallel'
    npm_config_cache              '.npm'
    AWS_CONFIG_FILE               '.aws'
    DOTNET_CLI_HOME               '.dotnet'
    OLLAMA_MODELS                 '.ollama'
    NODE_REPL_HISTORY             '.node_repl_history'
    PYTHON_HISTORY                '.python_history'
)

# Relocatable but NOT yet declared here: path → the variable that would move it. Reported
# only when the path exists and the variable is unset. Setting the variable does not migrate
# existing data, which the report says explicitly — that caveat is the whole reason these
# are suggestions rather than something install.sh does silently.
typeset -gA XDG_AUDIT_AVAILABLE=(
    # NODE_REPL_HISTORY, PYTHON_HISTORY, DOTNET_CLI_HOME and OLLAMA_MODELS used to live here.
    # They are now exported by .zshenv and migrated by install.sh, so they are declared
    # relocations (see XDG_AUDIT_DECLARED) rather than pending suggestions.
    '.docker'             'DOCKER_CONFIG'
    '.gradle'             'GRADLE_USER_HOME'
    '.m2'                 'MAVEN_OPTS (-Dmaven.repo.local)'
    '.terraform.d'        'TF_CLI_CONFIG_FILE'
    '.kube'               'KUBECONFIG'
    '.android'            'ANDROID_USER_HOME'
    '.gnome'              '(none — desktop session state)'
)

# Declared, set, and still partially bypassed: the variable governs SOME of what the tool
# writes but not all of it. Each value is the reason, printed verbatim, because "the var is
# set but the path is still here" would otherwise read as a stale leftover and invite a
# deletion that breaks the tool.
typeset -gA XDG_AUDIT_PARTIAL=(
    '.aws'         'AWS_CONFIG_FILE/AWS_SHARED_CREDENTIALS_FILE cover config+credentials only; .aws/cli is the SSO cache'
    '.ollama'      'OLLAMA_MODELS relocates the model blobs only; config.json and history have no override and stay here'
    '.yarn'        'YARN_CACHE_FOLDER governs the cache only; ~/.yarn/bin holds global binaries and has no override'
    # Both of these read their env var AND the hardcoded ~/.<name> default, on purpose. The
    # two trees are live at once by design, so there is nothing to reconcile and nothing to
    # delete — which is why they belong here rather than in the divergent class.
    '.claude'      'CLAUDE_CONFIG_DIR moves most state, but Claude Code still reads ~/.claude/CLAUDE.md and ~/.claude/settings.json (hooks) from the default path'
    '.codex'       'CODEX_HOME moves most state, but codex still writes ~/.codex/sqlite/ (queue, thread_history, memories)'
    '.wget-hsts'   'WGETRC relocates wgetrc itself; the HSTS store needs a separate hsts-file= inside it'
    '.viminfo'     'vim writes $XDG_DATA_HOME/vim/viminfo; a stray file here means some vim ran without the config'
)

# No env var exists to move these. Counted, never listed.
#
# Grouped by WHY, because that is what decides whether an entry may ever leave this list:
# a tool that later ships an XDG variable moves to XDG_AUDIT_AVAILABLE, whereas bash's rc
# files and kernel-written markers never can.
typeset -ga XDG_AUDIT_IGNORE=(
    # Hardcoded by the program, no override exists
    '.bashrc' '.bash_logout' '.bash_history' '.bash_profile' '.profile'
    '.vim' '.vimrc' '.gitconfig' '.gitignore' '.lesshst' '.yarnrc' '.Xresources'
    '.Xauthority' '.ICEauthority' '.gtkrc-2.0' '.dbus' '.gnome'
    # Written by the system or the session, not by a user-configurable tool
    '.motd_shown' '.sudo_as_admin_successful' '.landscape' '.pki' '.nv'
    # Remote/dev-container runtimes: the host decides the path, not this machine
    '.vscode-server' '.vscode-remote-containers' '.vscode'
    # XDG roots and things already living inside them
    '.cache' '.config' '.local' '.ssh' '.dotfiles'
    '.gnupg' '.password-store' '.cargo'
    # atuin is fully XDG already; ~/.atuin/logs is a hardcoded log path with no override
    '.atuin'
    # zsh state — ZDOTDIR already relocates the rc files; these are strays or caches
    '.zshenv' '.zshrc' '.zprofile' '.zlogin' '.zlogout' '.zsh_history' '.zcompdump'
    # AI/dev CLIs that hardcode a dotdir. Several DO read an env var (CLAUDE_CONFIG_DIR,
    # CODEX_HOME) and those are in XDG_AUDIT_DECLARED instead; the ones here have none as
    # of this writing. Recheck on a major version bump rather than assuming it is permanent.
    '.claude.json' '.codegraph' '.copilot' '.gemini' '.graft' '.kimi' '.kimi-code'
    '.ws-devtools' '.supabase' '.unsloth' '.ollama-history'
    # Hand-made backups: yours, not a tool's, so not this report's business
    '.aws.bak' '.rustup.bak' '.docker.bak' '.wget-hsts.bak'
)

function xdg_audit::usage() {
    print -r -- "Usage: xdg-audit [-h|--help] [--quiet] [--ids]"
    print -r -- ""
    print -r -- "Audit \$HOME for application state that is, or could be, XDG-relocated."
    print -r -- "Read-only: prints findings and the fix for each, and never removes anything."
    print -r -- ""
    print -r -- "Findings are grouped into four classes:"
    print -r -- "  stale       a relocation is declared, the new location has the data, the legacy"
    print -r -- "              path is older and holds nothing unique — genuinely safe to remove"
    print -r -- "  divergent   both locations are live: the legacy path is newer, or holds files the"
    print -r -- "              new one lacks. Two real copies. Never delete these blind"
    print -r -- "  incomplete  a relocation is declared but the new location does NOT exist, so"
    print -r -- "              the legacy path is still the only copy — never delete these"
    print -r -- "  partial     the variable is set but does not govern everything the tool writes"
    print -r -- "  available   relocatable, no variable set yet — the export line is printed"
    print -r -- ""
    print -r -- "Anything in none of those, and not on the known-unrelocatable ignore list, is"
    print -r -- "reported as 'unclassified' so a newly-arrived dotfile gets noticed rather than"
    print -r -- "silently absorbed. That is what keeps the tables above from going stale."
    print -r -- ""
    print -r -- "Options:"
    print -r -- "  --quiet   Suppress the per-finding detail; print only the verdict line."
    print -r -- "  --ids     Print just the offending paths, one per line (for scripting)."
}

# Resolve a declared legacy path to its finding class. Echoes "stale", "incomplete", or
# nothing at all when the variable is unset (nothing was declared, so nothing is wrong).
#
# "Populated" is deliberately stricter than "exists": a relocation that created an EMPTY
# directory at the new location has not actually moved anything, and calling the legacy copy
# stale on that basis is how you would lose the only real data.
# Deliberately tests ONLY the exact path the variable names. An earlier version tried to be
# clever — "if the target looks like a file, compare its parent directory instead", detected
# via `${target} == *.*` — and got the single most dangerous case exactly backwards:
# RUSTUP_HOME=~/.config/.rustup contains a dot, so it walked up to ~/.config, found that
# populated, and pronounced the 8.1M ~/.rustup safe to delete when it was the only copy.
#
# "Twin exists and is populated" is ALSO not sufficient, which cost a second rewrite. Every
# one of the four paths this originally called stale turned out to be unsafe to delete:
#
#   ~/.rustup  modified a week AFTER $RUSTUP_HOME — something still writes to the old path,
#              so the variable is not being honoured by whatever that is
#   ~/.codex   live sqlite databases (queue, thread_history, memories), touched the same day
#   ~/.claude  settings.json and CLAUDE.md DIFFER from the XDG copies, and
#              helpers/graft-hooks.cjs exists only in the legacy tree
#   ~/.yarn    holds bin/create-playwright — a global binary, which YARN_CACHE_FOLDER was
#              never going to relocate because it governs the cache and nothing else
#
# So a legacy path is only clutter when all three hold: the twin is populated, the twin is
# at least as recently written as the legacy path, and the legacy tree contains nothing the
# twin lacks. Anything else is DIVERGENT — two live copies needing a human — and calling
# that "safe to remove" is the one failure mode here that destroys data.
function xdg_audit::classify() {
    local var="${1}" legacy="${2}"
    local target="${(P)var}"
    [[ -n "${target}" ]] || return 1

    [[ -e "${target}" ]] || { print -r -- "incomplete"; return 0 }

    if [[ -d "${target}" ]]; then
        # "Populated" is stricter than "exists" on purpose: a relocation that created an
        # empty directory has not moved anything, and the legacy copy is still the data.
        local -a contents=( "${target}"/*(DN) )
        (( ${#contents} )) || { print -r -- "incomplete"; return 0 }
    fi

    # \( -type f -o -type l \), never bare -type f: a tree holding only SYMLINKS has no
    # regular files, so a -type f probe returns nothing, BOTH tests below are skipped, and
    # the path falls through to "stale" without having been examined at all. ~/.yarn is
    # exactly that shape — a single symlink pointing at a live global binary.
    #
    # Test 1 — is the legacy path still being written to? Compare the newest FILE in each
    # tree, not the directory mtimes: a directory's mtime tracks only its own entries, so a
    # write deep inside leaves the top level untouched and the check would miss it.
    local newest_legacy newest_target
    newest_legacy="$(find "${legacy}" \( -type f -o -type l \) -printf '%T@\n' 2>/dev/null | sort -rn | head -1)"
    newest_target="$(find "${target}" \( -type f -o -type l \) -printf '%T@\n' 2>/dev/null | sort -rn | head -1)"
    if [[ -n "${newest_legacy}" && -n "${newest_target}" ]]; then
        (( ${newest_legacy%%.*} > ${newest_target%%.*} )) && { print -r -- "divergent"; return 0 }
    fi

    # Test 2 — does the legacy tree hold anything the twin lacks, by path or by content?
    # Bounded at 5000 files: beyond that the comparison costs more than it is worth, and
    # test 1 has already caught the common "still being written" case.
    if [[ -d "${legacy}" && -d "${target}" ]]; then
        local -i n=$(find "${legacy}" \( -type f -o -type l \) 2>/dev/null | wc -l)
        if (( n > 0 && n <= 5000 )); then
            local rel
            for rel in ${(f)"$(find "${legacy}" \( -type f -o -type l \) -printf '%P\n' 2>/dev/null)"}; do
                [[ -e "${target}/${rel}" ]] || { print -r -- "divergent"; return 0 }
                cmp -s "${legacy}/${rel}" "${target}/${rel}" || { print -r -- "divergent"; return 0 }
            done
        fi
    fi

    print -r -- "stale"
    return 0
}

function xdg_audit() {
    emulate -L zsh
    setopt local_options null_glob extended_glob

    local quiet=0 ids_only=0 arg
    for arg in "$@"; do
        case "${arg}" in
            (-h|--help) xdg_audit::usage; return 0 ;;
            (--quiet)   quiet=1 ;;
            (--ids)     ids_only=1 ;;
            (*) print -ru2 -- "xdg-audit: unknown option '${arg}'"; return 2 ;;
        esac
    done

    zmodload -F zsh/stat b:zstat 2>/dev/null

    local -a f_stale=() f_divergent=() f_incomplete=() f_partial=() f_available=() f_unclassified=()
    # hpath, NOT path. `path` is zsh's array tied to $PATH, and `local path` keeps the tie
    # rather than breaking it — so `for path in ~/.*` silently overwrites PATH for the whole
    # function. The symptom is not an error: every external command afterwards fails to
    # resolve and its capture comes back EMPTY, so the large-directory scan quietly decided
    # nothing in $HOME was over 100M. Same trap applies to cdpath, fignore, manpath.
    local name hpath var target klass

    # ---- class 1: declared relocations whose legacy path survives --------------------
    for var legacy in "${(@kv)XDG_AUDIT_DECLARED}"; do
        hpath="${HOME}/${legacy}"
        [[ -e "${hpath}" ]] || continue
        # A path with a PARTIAL entry is never reported as stale: the variable genuinely did
        # relocate part of what the tool writes, so "safe to remove" would be false and would
        # take the uncovered remainder (~/.aws/cli, the SSO cache) with it.
        (( ${+XDG_AUDIT_PARTIAL[${legacy}]} )) && continue
        klass="$(xdg_audit::classify "${var}" "${hpath}")" || continue
        target="${(P)var}"
        case "${klass}" in
            (stale)     f_stale+=( "${legacy}|${var}|${target}" ) ;;
            (divergent) f_divergent+=( "${legacy}|${var}|${target}" ) ;;
            (*)         f_incomplete+=( "${legacy}|${var}|${target}" ) ;;
        esac
    done

    # ---- class 1b: declared, set, but only partially governing -----------------------
    for name reason in "${(@kv)XDG_AUDIT_PARTIAL}"; do
        [[ -e "${HOME}/${name}" ]] && f_partial+=( "${name}|${reason}" )
    done

    # ---- class 2: relocatable, nothing declared --------------------------------------
    for name var in "${(@kv)XDG_AUDIT_AVAILABLE}"; do
        [[ -e "${HOME}/${name}" ]] || continue
        # Already covered by class 1 on this host — the var IS set, so it is not "available".
        [[ "${var}" == \(* ]] || [[ -n "${(P)var}" ]] && continue
        f_available+=( "${name}|${var}" )
    done

    # ---- class 3 + catch-all ---------------------------------------------------------
    # D glob qualifier to see dotfiles; (N) so an empty $HOME is not an error. Everything
    # already accounted for above is skipped, so what remains is genuinely unrecognised.
    local -a accounted=(
        ${XDG_AUDIT_IGNORE[@]}
        ${(v)XDG_AUDIT_DECLARED}
        ${(k)XDG_AUDIT_AVAILABLE}
        ${(k)XDG_AUDIT_PARTIAL}
    )
    local -i ignored=0
    local -a entries=( "${HOME}"/.*(DN^/) "${HOME}"/.*(DN/) )
    for hpath in "${entries[@]}"; do
        name="${hpath:t}"
        [[ "${name}" == (.|..) ]] && continue
        if (( ${accounted[(Ie)${name}]} )); then
            (( ignored++ ))
            continue
        fi
        f_unclassified+=( "${name}" )
    done

    # ACTIONABLE findings only. f_partial is deliberately excluded: every entry in it ends
    # with "and stays here" or "has no override" — they are permanent properties of how those
    # tools behave, not work items. Counting them meant a fully clean machine reported six
    # findings every week and maintain raised a health warning about it, which is exactly the
    # fire-on-healthy-state failure this tool exists to avoid.
    local -i findings=$(( ${#f_stale} + ${#f_divergent} + ${#f_incomplete} + ${#f_available} + ${#f_unclassified} ))

    # --ids: the offending paths only, for a caller that wants to act on them.
    if (( ids_only )); then
        local entry
        # ACTIONABLE paths only, matching what `findings` counts. f_partial is excluded: a
        # caller piping --ids into something wants paths it can act on, and a partial-coverage
        # path is one it must not touch.
        for entry in "${f_stale[@]}" "${f_divergent[@]}" "${f_incomplete[@]}" "${f_available[@]}"; do
            print -r -- "~/${entry%%|*}"
        done
        # Guarded: `print -rl --` on an empty array emits a blank line, which a caller reading
        # the list line-by-line would treat as a path.
        (( ${#f_unclassified} )) && print -rl -- ${f_unclassified[@]/#/\~/}
        return $(( findings > 0 ))
    fi

    if (( ! quiet )); then
        local entry rest
        if (( ${#f_stale} )); then
            print -r -- "  stale (relocated, legacy path is left-over clutter):"
            for entry in "${(o)f_stale[@]}"; do
                rest="${entry#*|}"
                printf '    %-24s %-22s → %s\n' "~/${entry%%|*}" "${rest%%|*}" "${rest#*|}"
            done
            # Built in a loop rather than by nesting modifiers over the array: a bare
            # ${${arr[@]}%%|*} applies to the JOINED string and silently yields one element.
            local -a stale_paths=()
            for entry in "${(o)f_stale[@]}"; do stale_paths+=( "~/${entry%%|*}" ); done
            print -r -- "    → verify, then remove: ${(j: :)stale_paths}"
        fi

        if (( ${#f_divergent} )); then
            print -r -- "  divergent (BOTH locations are live — reconcile by hand, do NOT delete):"
            for entry in "${(o)f_divergent[@]}"; do
                rest="${entry#*|}"
                printf '    %-24s %-22s ↔ %s\n' "~/${entry%%|*}" "${rest%%|*}" "${rest#*|}"
            done
            print -r -- "    → the legacy tree is newer, or holds files the new location lacks"
            print -r -- "    → diff -rq <legacy> <new>   to see what differs"
        fi

        if (( ${#f_incomplete} )); then
            print -r -- "  incomplete (declared, but the NEW location does not exist — do NOT delete):"
            for entry in "${(o)f_incomplete[@]}"; do
                rest="${entry#*|}"
                printf '    %-24s %-22s → %s (missing)\n' "~/${entry%%|*}" "${rest%%|*}" "${rest#*|}"
            done
            print -r -- "    → the legacy path is still the only copy; move it, or unset the variable"
        fi

        if (( ${#f_unclassified} )); then
            print -r -- "  unclassified (in none of the tables — triage and add it to one):"
            print -rl -- ${${(o)f_unclassified[@]}/#/    \~/}
        fi

        # Partial coverage is counted, never listed. Each entry is a permanent property of
        # how that tool behaves — "and stays here", "has no override" — so the detail is
        # reference material that belongs in XDG_AUDIT_PARTIAL, not in a report you read
        # weekly. The count alone says "checked, nothing to do".
        (( ${#f_partial} )) && print -r -- "  ${#f_partial} path(s) with documented partial coverage — no action needed"
        print -r -- "  (${ignored} known-unrelocatable entr$( (( ignored == 1 )) && print -n y || print -n ies) ignored)"
    fi

    if (( findings )); then
        print -r -- "${findings} XDG finding(s): ${#f_stale} stale, ${#f_divergent} divergent, ${#f_incomplete} incomplete, ${#f_available} available, ${#f_unclassified} unclassified"
    else
        print -r -- "XDG layout clean — nothing actionable in \$HOME"
    fi
    return $(( findings > 0 ))
}

alias xdg-audit="xdg_audit"
