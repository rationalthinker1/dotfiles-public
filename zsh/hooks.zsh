# =======================================================================================
# Context-Aware Navigation
# =======================================================================================

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
# Automatically activates Python venv and shows README after cd
# This uses chpwd hook instead of overriding cd, so it works with Enhancd
# Note: May conflict with direnv - disable if using direnv
function _context_aware_chpwd() {
  # Auto-activate Python venv
  if [[ -d .venv/bin ]]; then
    [[ -z "$VIRTUAL_ENV" ]] && source .venv/bin/activate
  fi

  # Show project info if README exists
  if [[ -f README.md ]]; then
    echo "📄 README.md present"
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
      # Warn about untrusted .dirrc files
      print -P "%F{yellow}⚠️  Found .dirrc in untrusted location: %F{cyan}$PWD%f"
      print -P "%F{yellow}Run 'source .dirrc' to load it manually%f"
    ;;
  esac
}
chpwd_functions+=(load-local-conf)
