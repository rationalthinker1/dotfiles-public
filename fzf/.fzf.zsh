# Setup fzf
# ---------
if [[ ! "$PATH" == */home/canaan/.fzf/bin* ]]; then
  export PATH="${PATH:+${PATH}:}/home/canaan/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/home/canaan/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/home/canaan/.fzf/shell/key-bindings.zsh"
