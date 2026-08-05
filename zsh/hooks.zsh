# =======================================================================================
# Context-Aware Navigation
# =======================================================================================

# Ensure hook arrays are properly initialized
typeset -ga precmd_functions
typeset -ga chpwd_functions

# Reset cursor on each new prompt (skip in tmux)
if [[ -z "$TMUX" ]]; then
  function reset_cursor() {
    echo -ne '\e[5 q'
  }
  precmd_functions+=(reset_cursor)
fi

# 🪟 Set terminal title on each prompt
function _set_terminal_title() {
  print -Pn "\e]0;%n@%m: %~\a"
}
precmd_functions+=(_set_terminal_title)

# 🐍 Smart directory context hook - Works with Enhancd
# Automatically activates a Python venv after cd
# This uses chpwd hook instead of overriding cd, so it works with Enhancd
# Note: May conflict with direnv - disable if using direnv
#
# Keep this hook silent on stdout. chpwd fires inside command substitutions too, so
# anything echoed here is captured by callers such as `x=$(cd "$dir" && some-command)`
# and corrupts their result. Anything informational belongs on stderr (>&2).
function _context_aware_chpwd() {
  # Auto-activate Python venv
  if [[ -d .venv/bin ]]; then
    [[ -z "$VIRTUAL_ENV" ]] && source .venv/bin/activate
  fi
}

# Add to chpwd_functions array (runs after every directory change)
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _context_aware_chpwd

# 🔁 Auto-source `.dirrc` when entering a directory (SAFE version)
function load-local-conf() {
  local dirrc=.dirrc
  [[ -f $dirrc ]] || return 0

  # Only auto-load from trusted directories (HOME and its subdirectories)
  case $PWD in
    $HOME/*|$HOME)
      source "$dirrc"
    ;;
    *)
      # Warn about untrusted .dirrc files. Written to stderr (-u2): this runs from a
      # chpwd hook, which also fires inside command substitutions, so anything on
      # stdout here would be captured by the caller instead of shown to the user.
      print -Pu2 "%F{yellow}⚠️  Found .dirrc in untrusted location: %F{cyan}$PWD%f"
      print -Pu2 "%F{yellow}Run 'source .dirrc' to load it manually%f"
    ;;
  esac
}
chpwd_functions+=(load-local-conf)
