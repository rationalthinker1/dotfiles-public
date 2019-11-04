# Setup fzf
# ---------
if [[ ! "$PATH" == */home/${USER}/.config/fzf/bin* ]]; then
  export PATH="${PATH:+${PATH}:}/home/${USER}/.config/fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/home/${USER}/.config/fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/home/${USER}/.config/fzf/shell/key-bindings.zsh"
