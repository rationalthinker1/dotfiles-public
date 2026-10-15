# ==============================================================================
# termux.zsh - Termux-only interactive config (sourced by .zshrc when HOST_OS=termux)
# ==============================================================================
# Kept out of aliases.zsh so the phone's half of the config reads in one place and no other
# host pays even a test for it. Everything termux-* below except termux-open needs the
# Termux:API *app* (F-Droid, same source as Termux), not just the termux-api package —
# without the app those commands block forever, hence the `timeout` on each one.
# ==============================================================================

#---------------------------------------------------------------------------------------
# Package management — the apt aliases in aliases.zsh switch off here, so same names on pkg.
#---------------------------------------------------------------------------------------
# `command`: zsh expands an alias's first word as an alias too, so any future `pkg` alias
# would silently hijack all five (aliases.zsh's `pkg` → vim package.json once did).
alias install="command pkg install -y"
alias remove="command pkg uninstall"
alias update="command pkg update -y"
alias upgrade="command pkg upgrade -y"
alias search="command pkg search"

#---------------------------------------------------------------------------------------
# Clipboard + open — so `… | pbcopy` and OMZ copyfile (which calls clipcopy) work here.
#---------------------------------------------------------------------------------------
function _termux_api() {
    timeout 5 "${@}" && return 0
    print -ru2 -- "${1}: no answer — is the Termux:API app installed?"
    return 1
}
function pbcopy()    { _termux_api termux-clipboard-set "${@}" }
function pbpaste()   { _termux_api termux-clipboard-get }
function clipcopy()  { if [[ -n "${1}" ]]; then pbcopy < "${1}"; else pbcopy; fi }
function clippaste() { pbpaste }
# termux-open ships with termux-tools, not the API app: files open in their Android app,
# URLs in the browser. --chooser always asks which app.
alias open="termux-open"

#---------------------------------------------------------------------------------------
# "Long command finished" notification — switch apps during `pkg upgrade` and get pinged.
#---------------------------------------------------------------------------------------
# Threshold in seconds; set TERMUX_NOTIFY_MIN in local.zsh to change it, 0 to disable.
typeset -gi TERMUX_NOTIFY_MIN="${TERMUX_NOTIFY_MIN:-30}"
# Full-screen and session commands: you were watching them, a ping on exit is noise.
typeset -ga TERMUX_NOTIFY_SKIP=(
    vim nvim vi less more man ssh mosh tmux htop top btop btm lazygit yazi ranger
    broot fzf tig watch tail
)
typeset -g _termux_cmd=""
typeset -gF _termux_start=0

zmodload zsh/datetime

function _termux_notify_preexec() {
    _termux_cmd="${1}"
    _termux_start="${EPOCHREALTIME}"
}

function _termux_notify_precmd() {
    local -i rc="${?}"
    (( _termux_start )) || return 0
    local -i elapsed=$(( EPOCHREALTIME - _termux_start ))
    local cmd="${_termux_cmd}"
    _termux_start=0
    (( TERMUX_NOTIFY_MIN > 0 && elapsed >= TERMUX_NOTIFY_MIN )) || return 0
    (( ${TERMUX_NOTIFY_SKIP[(Ie)${${(z)cmd}[1]}]} )) && return 0
    (( $+commands[termux-notification] )) || return 0

    local mark="✓"
    (( rc )) && mark="✗ ${rc}"
    # Backgrounded and disowned: the prompt must not wait on the API round-trip, and a
    # missing API app would otherwise hang it for the full timeout.
    ( timeout 10 termux-notification \
        --id dotfiles-long-cmd \
        --title "${mark} after $(( elapsed / 60 ))m$(( elapsed % 60 ))s" \
        --content "${cmd[1,200]}" &>/dev/null ) &!
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _termux_notify_preexec
add-zsh-hook precmd _termux_notify_precmd
