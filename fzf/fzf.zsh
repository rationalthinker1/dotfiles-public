# Setup fzf
# ---------
if [[ ! "$PATH" == */home/nookta/.fzf/bin* ]]; then
  export PATH="${PATH:+${PATH}:}/home/nookta/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/home/nookta/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/home/nookta/.fzf/shell/key-bindings.zsh"
