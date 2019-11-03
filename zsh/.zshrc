#export TERM="xterm-256color"
export LOCAL_CONFIG="/home/${USER}/.config"
export ZDOTDIR="${LOCAL_CONFIG}/zsh"
export ADOTDIR="${ZDOTDIR}/antigen"
export ZSH="${ZDOTDIR}/oh-my-zsh"

#=======================================================================================
# Basic Settings
#=======================================================================================
HISTFILE="${ZDOTDIR}"/.zsh_history
HISTSIZE=20000             # bash history will save N commands
HISTFILESIZE="${HISTSIZE}" # bash will remember N commands
HISTCONTROL=ignoreboth     # ingore duplicates and spaces
HISTIGNORE='&:ls:ll:la:cd:exit:clear:history:ls:[bf]g:[cb]d:b:exit:[ ]*:..'
setopt CORRECT                    # Try to correct command line spelling
setopt AUTO_CD
setopt PUSHD_IGNORE_DUPS
unsetopt MENU_COMPLETE            # DO NOT AUTOSELECT THE FIRST COMPLETION ENTRY
unsetopt FLOWCONTROL
setopt AUTO_MENU                  # SHOW COMPLETION MENU ON SUCCESIVE TAB PRESs
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
setopt HIST_REDUCE_BLANKS
setopt INC_APPEND_HISTORY         # append history list to the history file (important for multiple parallel zsh sessions!)
setopt SHARE_HISTORY              # import new commands from the history file also in other zsh-session
setopt EXTENDED_HISTORY           # save each command's beginning timestamp and the duration to the history file
setopt HIST_IGNORE_ALL_DUPS       # If a new command line being added to the history list duplicates an older one, the older command is removed from the list
setopt HIST_IGNORE_SPACE          # remove command lines from the history list when the first character on the line is a space

# Vi mode
bindkey -v
autoload -U edit-command-line
zle -N edit-command-line
bindkey '^E' edit-command-line                   # Opens Vim to edit current command line
bindkey -M vicmd v edit-command-line

# loading autocompletion
autoload -U +X compinit && compinit
autoload -U +X bashcompinit && bashcompinit
bashcompinit -i

# https://stackoverflow.com/questions/21806168/vim-use-ctrl-q-for-visual-block-mode-in-vim-gnome
stty start undef


#=======================================================================================
# Antigen
#=======================================================================================
source "${ZDOTDIR}/antigen.zsh"
export TERM="xterm-256color"
# Load the oh-my-zsh's library.
antigen use oh-my-zsh

# Bundles from the default repo (robbyrussell's oh-my-zsh).
antigen bundle git
antigen bundle docker
antigen bundle docker-compose
antigen bundle zpm-zsh/ssh
antigen bundle g-plane/zsh-yarn-autocompletions
antigen bundle thetic/extract
antigen bundle voronkovich/apache2.plugin.zsh
antigen bundle command-not-found
antigen bundle hlissner/zsh-autopair
antigen bundle zdharma/fast-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-history-substring-search

# Load the theme.
antigen theme romkatv/powerlevel10k
#antigen theme https://github.com/caiogondim/bullet-train-oh-my-zsh-theme bullet-train
#antigen theme bhilburn/powerlevel9k powerlevel9k

# Tell antigen that you're done.
antigen apply

#=======================================================================================
# Aliases and functions
#=======================================================================================
if [ -f "${LOCAL_CONFIG}"/zsh/aliases.zsh ]; then
    source "${LOCAL_CONFIG}"/zsh/aliases.zsh
fi

#=======================================================================================
# Local Aliases and functions
#=======================================================================================
if [ -f "${LOCAL_CONFIG}"/zsh/local.zsh ]; then
    source "${LOCAL_CONFIG}"/zsh/local.zsh
fi

if [ -f "${HOME}"/.bash_local ]; then
    source "${HOME}"/.bash_local
fi

# Load fzf
[ -f "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh ] && source "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh
# load powerlevel10k settings
[[ -f "${ZDOTDIR}"/.p10k.zsh ]] && source "${ZDOTDIR}"/.p10k.zsh

# Load tmux
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
	exec tmux -f "${LOCAL_CONFIG}"/tmux/tmux.conf
fi
