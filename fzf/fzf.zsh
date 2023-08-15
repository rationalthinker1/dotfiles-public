# Setup fzf
# ---------
if [[ ! "$PATH" == */home/raza/.config/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/raza/.config/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/home/raza/.config/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/home/raza/.config/.fzf/shell/key-bindings.zsh"
