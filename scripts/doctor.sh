#!/usr/bin/env bash
#
# doctor.sh — verify a .dotfiles deployment end to end.
#
#   ./scripts/doctor.sh              # checks only (safe, read-only, no sudo)
#   ./scripts/doctor.sh --install    # run install.sh first, then check
#   ./scripts/doctor.sh | tee /tmp/doctor.log
#
# Deliberately does NOT use `set -e`: every check must run even after one fails,
# because the report is the whole point.
#
# Prints names, versions and pass/fail only — never the CONTENTS of any tracked
# file. Private paths are reported as "present", never read, so the output is
# safe to paste into a chat or an issue.

DOTFILES_ROOT="${DOTFILES_ROOT:-${HOME}/.dotfiles}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"

RUN_INSTALL=false
[[ "${1:-}" == "--install" ]] && RUN_INSTALL=true

# Colour only when attached to a terminal, so `| tee` and pasted output stay clean
if [[ -t 1 ]]; then
    C_OK=$'\033[32m'; C_BAD=$'\033[31m'; C_WARN=$'\033[33m'; C_HEAD=$'\033[1m'; C_OFF=$'\033[0m'
else
    C_OK=""; C_BAD=""; C_WARN=""; C_HEAD=""; C_OFF=""
fi

pass=0; fail=0; warn=0
declare -a FAILURES=()

ok()    { printf '  %sPASS%s  %s\n' "${C_OK}" "${C_OFF}" "$*"; pass=$((pass+1)); }
bad()   { printf '  %sFAIL%s  %s\n' "${C_BAD}" "${C_OFF}" "$*"; fail=$((fail+1)); FAILURES+=("$*"); }
meh()   { printf '  %sWARN%s  %s\n' "${C_WARN}" "${C_OFF}" "$*"; warn=$((warn+1)); }
info()  { printf '        %s\n' "$*"; }
head1() { printf '\n%s━━ %s ━━%s\n' "${C_HEAD}" "$*" "${C_OFF}"; }

# A symlink is correct only if it resolves INTO the dotfiles repo.
check_link() {
    local target="$1" label="${2:-$1}" resolved
    label="${label/#${HOME}/\~}"
    if [[ -L "${target}" ]]; then
        resolved="$(readlink -f "${target}" 2>/dev/null)"
        if [[ -e "${target}" && "${resolved}" == "${DOTFILES_ROOT}"/* ]]; then
            ok "${label}"
        elif [[ ! -e "${target}" ]]; then
            bad "${label} — DANGLING symlink -> $(readlink "${target}")"
        else
            bad "${label} — resolves outside the repo: ${resolved}"
        fi
    elif [[ -e "${target}" ]]; then
        bad "${label} — exists but is NOT a symlink"
    else
        bad "${label} — missing"
    fi
}

#=======================================================================================
head1 "0. Environment"
#=======================================================================================
info "date:    $(date -Is 2>/dev/null || date)"
info "kernel:  $(uname -sr)"
info "distro:  $( (. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME}") || echo unknown)"
info "shell:   ${SHELL}"
info "wsl:     ${WSL_DISTRO_NAME:-no}"

#=======================================================================================
head1 "1. Coreutils provider"
#=======================================================================================
info "mkdir:   $(command -v mkdir)"
info "version: $(mkdir --version 2>&1 | head -1)"
if command -v dpkg &>/dev/null; then
    for p in coreutils-from-gnu coreutils-from-uutils rust-coreutils; do
        dpkg -l "${p}" 2>/dev/null | grep -q '^ii' && info "package: ${p} installed"
    done
fi
# The Ubuntu 26.04 uutils regression that aborts install.sh under set -e.
_probe="$(mktemp -d)"
if mkdir -p "${_probe}" 2>/dev/null; then
    ok "mkdir -p on an existing directory returns 0 (POSIX-correct)"
else
    bad "mkdir -p on an existing directory returns non-zero — install.sh aborts under set -e"
    info "fix: sudo apt-get remove coreutils-from-uutils --allow-remove-essential"
fi
rmdir "${_probe}" 2>/dev/null

#=======================================================================================
head1 "2. Build toolchain"
#=======================================================================================
for c in gcc g++ make; do
    if command -v "${c}" &>/dev/null; then ok "${c}: $("${c}" --version 2>&1 | head -1)"; else bad "${c}: not on PATH"; fi
done
if command -v dpkg &>/dev/null; then
    if dpkg -l build-essential 2>/dev/null | grep -q '^ii'; then
        ok "build-essential installed"
    else
        bad "build-essential NOT installed — mise cannot compile vim"
        info "fix: sudo apt-get install build-essential"
    fi
fi
if command -v python3 &>/dev/null; then
    if python3 -c 'import sysconfig,os;raise SystemExit(0 if os.path.exists(sysconfig.get_config_h_filename()) else 1)' 2>/dev/null; then
        ok "python3 development headers present (vim +python3 links against them)"
    else
        bad "python3-dev headers missing — vim would build WITHOUT python3"
    fi
fi

#=======================================================================================
head1 "3. Repository state"
#=======================================================================================
if [[ -d "${DOTFILES_ROOT}/.git" ]]; then
    ok "repo at ${DOTFILES_ROOT}"
    info "branch:  $(git -C "${DOTFILES_ROOT}" branch --show-current)"
    info "head:    $(git -C "${DOTFILES_ROOT}" log --oneline -1)"
    info "dirty:   $(git -C "${DOTFILES_ROOT}" status --porcelain | wc -l) file(s)"
    [[ -d "${DOTFILES_ROOT}/config" ]] && ok "config/ layout present" \
        || bad "config/ missing — layout migration has not landed here; run: git pull"
    for stale in zsh mise atuin gh kitty ranger broot alacritty tmux sheldon ripgrep fzf zi claude; do
        [[ -d "${DOTFILES_ROOT}/${stale}" && ! -L "${DOTFILES_ROOT}/${stale}" ]] \
            && meh "pre-migration leftover at repo root: ${stale}/"
    done
    [[ -e "${DOTFILES_ROOT}/.git/hooks/post-commit" ]] && ok "post-commit hook installed" \
        || meh "post-commit hook not installed — commits will not sync to public"
else
    bad "no git repo at ${DOTFILES_ROOT}"
fi

#=======================================================================================
if [[ "${RUN_INSTALL}" == "true" ]]; then
head1 "4. Running install.sh"
    echo "  (streaming; sudo may prompt)"
    ( cd "${DOTFILES_ROOT}" && ./install.sh ) 2>&1 | sed 's/^/  | /'
    rc="${PIPESTATUS[0]}"
    [[ "${rc}" -eq 0 ]] && ok "install.sh exited 0" \
        || bad "install.sh exited ${rc} — the last streamed line above is where it stopped"
else
head1 "4. install.sh (skipped — pass --install to run it)"
fi

#=======================================================================================
head1 "5. Symlinks"
#=======================================================================================
for t in .zshrc .zshenv .zprofile .zlogin .zlogout .vimrc .vim; do check_link "${HOME}/${t}"; done
for t in zsh atuin ranger sheldon ripgrep kitty broot alacritty tmux mimeapps.list \
         mise/config.toml gh/config.yml git/ignore git/aliases.gitconfig \
         fzf/fzf.zsh zi/init.zsh \
         claude/commands claude/agents claude/skills claude/CLAUDE.md; do
    check_link "${XDG_CONFIG_HOME}/${t}"
done
check_link "${HOME}/.local/bin/memwatch"
# Presence only — contents are never read.
for p in "${XDG_CONFIG_HOME}/.aws" "${XDG_CONFIG_HOME}/password-store"; do
    [[ -e "${p}" ]] && info "private path present (not inspected): ${p/#${HOME}/\~}"
done

#=======================================================================================
head1 "6. XDG migration targets"
#=======================================================================================
if [[ -f "${XDG_CONFIG_HOME}/git/config" ]]; then
    ok "git identity at ~/.config/git/config"
    grep -q "aliases.gitconfig" "${XDG_CONFIG_HOME}/git/config" \
        && ok "git aliases [include] wired" || bad "git config does not include aliases.gitconfig"
else
    bad "no ~/.config/git/config — git identity missing"
fi
[[ -d "${XDG_CONFIG_HOME}/gnupg" ]] \
    && ok "GNUPGHOME at ~/.config/gnupg (perms $(stat -c '%a' "${XDG_CONFIG_HOME}/gnupg" 2>/dev/null))" \
    || meh "no ~/.config/gnupg"
[[ -f "${XDG_CONFIG_HOME}/wget/wgetrc" ]] && ok "wgetrc present (wget aborts without it)" \
    || bad "no ~/.config/wget/wgetrc"
[[ -e "${HOME}/.gitconfig" ]] && meh "legacy ~/.gitconfig still present — XDG migration skipped it" \
    || ok "no legacy ~/.gitconfig"

#=======================================================================================
head1 "7. mise toolchain"
#=======================================================================================
if command -v mise &>/dev/null; then
    ok "mise: $(mise --version 2>&1 | head -1)"
    for t in node python rustc cargo uv yarn vim; do
        if mise which "${t}" &>/dev/null; then
            ok "${t}: $(mise exec -- "${t}" --version 2>&1 | head -1)"
        else
            bad "${t}: not installed by mise"
        fi
    done
    if mise which vim &>/dev/null; then
        mise exec -- vim --version 2>/dev/null | grep -q '+python3' \
            && ok "vim built WITH +python3" \
            || bad "vim built WITHOUT python3 — rebuild: mise uninstall vim && mise install vim"
    fi
else
    bad "mise not on PATH"
fi

#=======================================================================================
head1 "8. Fonts"
#=======================================================================================
if command -v fc-list &>/dev/null; then
    info "fonts known to fontconfig: $(fc-list 2>/dev/null | wc -l)"
    info "installed families: $(ls -1 /usr/share/fonts/truetype 2>/dev/null | wc -l) truetype, $(ls -1 /usr/share/fonts/opentype 2>/dev/null | wc -l) opentype"
    [[ -f "${DOTFILES_ROOT}/fonts/.installed" ]] && ok "fonts/.installed marker written" \
        || meh "no fonts/.installed marker — font phase not completed (or skipped)"
    [[ -d "${DOTFILES_ROOT}/fonts/installations" ]] \
        && meh "fonts/installations/ left behind — font phase aborted before cleanup" \
        || ok "font extraction dir cleaned up"
else
    meh "fc-list absent (headless?) — font checks skipped"
fi

#=======================================================================================
head1 "9. Shell startup"
#=======================================================================================
if command -v zsh &>/dev/null; then
    ok "zsh: $(zsh --version)"
    [[ -f "${XDG_DATA_HOME}/zinit/zinit.git/zinit.zsh" ]] && ok "zinit installed" \
        || bad "zinit missing at ${XDG_DATA_HOME}/zinit/zinit.git"
    echo "  --- interactive startup stderr (empty is good; ziextract/cloudflared noise is expected on a fresh install) ---"
    zsh -ic 'exit' 2>&1 >/dev/null | head -25 | sed 's/^/  | /'
    start=$(date +%s%N)
    zsh -ic 'exit' >/dev/null 2>&1
    elapsed=$(( ($(date +%s%N) - start) / 1000000 ))
    info "interactive startup: ${elapsed} ms"
    (( elapsed < 1500 )) && ok "startup under 1.5 s" || meh "startup ${elapsed} ms"
    zdot="$(zsh -ic 'echo ${ZDOTDIR}' 2>/dev/null | tail -1)"
    [[ -n "${zdot}" ]] && ok "ZDOTDIR resolves to ${zdot}" || bad "ZDOTDIR unset in interactive zsh"
    [[ "$(basename "${SHELL}")" == "zsh" ]] && ok "login shell is zsh" \
        || meh "login shell is ${SHELL} — run: chsh -s \$(command -v zsh)"
else
    bad "zsh not installed"
fi

#=======================================================================================
head1 "10. Core CLI tools"
#=======================================================================================
# Most of these are zinit-managed, so they are NOT on a non-interactive bash PATH —
# checking `command -v` alone reports every one of them as missing. Fall back to
# searching zinit's plugin tree, which is where `from'gh-r'` parks the binaries.
tool_version() {
    local bin="$1" out
    case "$(basename "${bin}")" in
        unzip) out="$("${bin}" -v 2>/dev/null | head -1)" ;;
        *)     out="$("${bin}" --version 2>/dev/null | head -1)"
               [[ -z "${out}" ]] && out="$("${bin}" -V 2>/dev/null | head -1)" ;;
    esac
    printf '%s' "${out:-(version unknown)}" | cut -c1-60
}
for c in git tmux fzf rg fd eza bat zoxide atuin broot delta gh jq curl unzip rsync cloudflared; do
    if bin="$(command -v "${c}" 2>/dev/null)"; then
        ok "${c}: $(tool_version "${bin}")"
    elif bin="$(find "${XDG_DATA_HOME}/zinit" -maxdepth 5 -name "${c}" -type f -perm -u+x 2>/dev/null | head -1)" \
         && [[ -n "${bin}" ]]; then
        ok "${c}: $(tool_version "${bin}")  [zinit, loads in interactive zsh]"
    else
        meh "${c}: not found on PATH or in zinit's plugin tree"
    fi
done

#=======================================================================================
head1 "SUMMARY"
#=======================================================================================
printf '  %s%d passed%s, %s%d failed%s, %s%d warnings%s\n' \
    "${C_OK}" "${pass}" "${C_OFF}" "${C_BAD}" "${fail}" "${C_OFF}" "${C_WARN}" "${warn}" "${C_OFF}"
if (( fail > 0 )); then
    echo
    echo "  Failures, in order:"
    for f in "${FAILURES[@]}"; do echo "    - ${f}"; done
fi
exit 0
