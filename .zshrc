#export TERM="xterm-256color"
export LOCAL_CONFIG="/home/${USER}/.config"
export ZSH="${LOCAL_CONFIG}/oh-my-zsh"
export ADOTDIR="${LOCAL_CONFIG}/antigen"
export PATH="/opt/anaconda3/bin:${PATH}"
source /home/"${USER}"/.dotfiles/.theme
#=======================================================================================
# Basic Settings
#=======================================================================================
export HISTSIZE=2000            # bash history will save N commands
export HISTFILESIZE="${HISTSIZE}" # bash will remember N commands
export HISTCONTROL=ignoreboth   # ingore duplicates and spaces
export HISTIGNORE='&:ls:ll:la:cd:exit:clear:history:ls:[bf]g:[cb]d:b:exit:[ ]*:..'
export VISUAL=vim


# Load tmux
if [[ ! $TERM =~ screen ]]; then
    exec tmux -f "${LOCAL_CONFIG}"/tmux/tmux.conf
fi
#=======================================================================================
# Antigen
#=======================================================================================
source "$ADOTDIR"/antigen.zsh
export TERM="xterm-256color"
# Load the oh-my-zsh's library.
antigen use oh-my-zsh

# Bundles from the default repo (robbyrussell's oh-my-zsh).
antigen bundle git
antigen bundle heroku
antigen bundle pip
antigen bundle lein
antigen bundle command-not-found
antigen bundle hlissner/zsh-autopair
antigen bundle zdharma/fast-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions
#antigen bundle unixorn/autoupdate-antigen.zshplugin

# Load the theme.
BULLETTRAIN_TIME_12HR=true
BULLETTRAIN_CONTEXT_DEFAULT_USER="$USER"
BULLETTRAIN_DIR_EXTENDED=0
antigen theme https://github.com/caiogondim/bullet-train-oh-my-zsh-theme bullet-train
#antigen theme bhilburn/powerlevel9k powerlevel9k

# Tell antigen that you're done.
antigen apply

autoload -U +X compinit && compinit
autoload -U +X bashcompinit && bashcompinit
bashcompinit -i

#=======================================================================================
# Aliases and functions
#=======================================================================================
if [ -f $HOME/.bash_aliases ]; then
    source $HOME/.bash_aliases
fi

#=======================================================================================
# Local Aliases and functions
#=======================================================================================
if [ -f $HOME/.bash_local ]; then
    source $HOME/.bash_local
fi

# Load fzf
[ -f "${LOCAL_CONFIG}"/fzf/.fzf.zsh ] && source "${LOCAL_CONFIG}"/fzf/.fzf.zsh
